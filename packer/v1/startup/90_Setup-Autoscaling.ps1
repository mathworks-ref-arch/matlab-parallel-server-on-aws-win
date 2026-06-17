# Set up MJS Cluster for Auto-Resizing
# https://www.mathworks.com/help/matlab-parallel-server/set-up-your-mjs-cluster-for-resizing.html
# Copyright 2026 The MathWorks, Inc.

function Get-AutoscalingArguments {
    <#
    .SYNOPSIS
        Build the autoscaling command-line arguments based on environment configuration.
    #>
    $UsePrivateIPMapping = if ($Env:CommunicationMode -eq 'PrivateIP') { 'True' } else { 'False' }
    $Arguments = "--use-private-ip-mapping $UsePrivateIPMapping"

    if ($Env:DnsSearchSuffix) {
        $Arguments += " --dns-search-suffix $Env:DnsSearchSuffix"
    }

    return $Arguments
}

function Get-PythonExecutablePath {
    <#
    .SYNOPSIS
        Get the full path to the Python executable.
    #>
    $PythonPath = (Get-Command 'py' -ErrorAction Stop).Source
    return $PythonPath
}

function Register-AutoscalingTask {
    <#
    .SYNOPSIS
        Register a scheduled task to periodically run the autoscaling script.
    .PARAMETER AutoscalingArgs
        Command-line arguments to pass to the autoscaling script.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$AutoscalingArgs
    )

    $TaskName = 'Autoscaling Task for MATLAB Parallel Server'

    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($ExistingTask) {
        Write-Output "Autoscaling task already exists"
        return
    }

    Write-Output "Creating autoscaling task"

    $PythonPath = Get-PythonExecutablePath
    Write-Output "Python executable found at: $PythonPath"
    $ScriptPath = "$Env:ProgramFiles\MathWorks\autoscaling\autoscaling.py"
    $PeriodInMinutes = 1

    $Action = New-ScheduledTaskAction `
        -Execute $PythonPath `
        -Argument "`"$ScriptPath`" $AutoscalingArgs"

    $Trigger = New-ScheduledTaskTrigger `
        -Once `
        -At (Get-Date) `
        -RepetitionInterval (New-TimeSpan -Minutes $PeriodInMinutes)

    $Principal = New-ScheduledTaskPrincipal `
        -UserId 'SYSTEM' `
        -LogonType ServiceAccount `
        -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal

    Write-Output "Autoscaling task '$TaskName' created successfully"
}

function Initialize-Autoscaling {
    <#
    .SYNOPSIS
        Set up autoscaling for the MJS cluster if conditions are met.
    #>
    if ($Env:NodeType -ne 'headnode') {
        Write-Output "Current node is not the head-node. Skipping autoscaling setup."
        return
    }

    if ($Env:EnableAutoscaling -ne 'Yes') {
        Write-Output "Autoscaling is not enabled. Skipping autoscaling setup."
        return
    }

    if ($Env:MATLABRelease -lt 'R2022a') {
        Write-Output "WARNING: Auto-Resizing is only available for R2022a and later"
        return
    }

    $AutoscalingArgs = Get-AutoscalingArguments
    Write-Output "Autoscaling arguments: $AutoscalingArgs"

    Register-AutoscalingTask -AutoscalingArgs $AutoscalingArgs
}

try {
    Initialize-Autoscaling
} catch {
    Write-Error "Failed to set up autoscaling: $_"
    throw
}
