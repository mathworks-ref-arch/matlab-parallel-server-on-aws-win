# Copyright 2022-2023 The MathWorks, Inc.

# This script defines MATLAB Job Scheduler Startup Parameters
# https://www.mathworks.com/help/matlab-parallel-server/define-startup-parameters.html

<#
.SYNOPSIS
    Edit the MJS startup parameters in the mjs_def

.PARAMETER ParameterName
.PARAMETER ParameterValue

.OUTPUTS
    0 if parameter was set successfully, non-zero on error.
#>
Function Edit-MJSDef {
    param (
        $ParameterName,
        $ParameterValue
    )

    (Get-Content $Env:MJSDefFile -Raw) -Replace "REM set $ParameterName=.*","set $ParameterName=$ParameterValue" | Set-Content $Env:MJSDefFile
    If (-not (Select-String -Pattern "^set $ParameterName=" -Path $Env:MJSDefFile)) {
        Write-Output "Failed to set parameter $ParameterName"
        Exit 1
    }
}

# Set folder used to store mjs checkpoint folders
Edit-MJSDef -ParameterName 'CHECKPOINTBASE' -ParameterValue $Env:CheckpointRoot

# Set MATLAB Job Scheduler Cluster Security
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html
If ($Env:SecurityLevel) {
    Edit-MJSDef -ParameterName 'SECURITY_LEVEL' -ParameterValue $Env:SecurityLevel

    # Generate default password for ADMIN_USER at Security Level 2 and 3
    If (([int]$Env:SecurityLevel -ge 2) -and -not (Test-Path $Env:MJSAdminPasswordFile)) {
        $MJSAdminPasswordRoot = Split-Path -Parent $Env:MJSAdminPasswordFile
        If (-not (Test-Path $MJSAdminPasswordRoot)) {
            New-Item -Path $MJSAdminPasswordRoot -ItemType Directory
        }
        Add-Type -AssemblyName 'System.Web'
        [System.Web.Security.Membership]::GeneratePassword(32,0) | Set-Content $Env:MJSAdminPasswordFile
    }
}

# Set Encrypted Communication
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html#bsohndi-1
Edit-MJSDef -ParameterName 'USE_SECURE_COMMUNICATION' -ParameterValue 'true'

# Set Cluster Command Verification
# https://www.mathworks.com/help/matlab-parallel-server/set-matlab-job-scheduler-cluster-security.html#mw_ca721746-0154-4d20-9a6e-753bed4d4058
Edit-MJSDef -ParameterName 'REQUIRE_SCRIPT_VERIFICATION' -ParameterValue 'true'

# Require MATLAB clients to present a certificate to connect to the job manager
Edit-MJSDef -ParameterName 'REQUIRE_CLIENT_CERTIFICATE' -ParameterValue 'true'

# Increase heap memory available to MJS
# https://www.mathworks.com/help/matlab-parallel-server/customize-startup-parameters.html
$MemoryMB = $(Get-ComputerInfo).OsTotalVisibleMemorySize / 1024
If ($Env:NodeType -eq 'headnode') {
    $JobManagerMaximumMemoryMB = 1024 + 5*$Env:MaxNodes*$Env:WorkersPerNode
    If ($JobManagerMaximumMemoryMB -gt $MemoryMB/2) {
        $JobManagerMaximumMemoryMB = [int]($MemoryMB/2)
    }

    Edit-MJSDef -ParameterName 'JOB_MANAGER_MAXIMUM_MEMORY' -ParameterValue "${JobManagerMaximumMemoryMB}m"

} Else {
    $WorkerMaximumMemoryMB = 1024 + 64*$Env:WorkersPerNode
    If ($WorkerMaximumMemoryMB -gt $MemoryMB/4) {
        $WorkerMaximumMemoryMB = [int]($MemoryMB/4)
    }

    Edit-MJSDef -ParameterName 'WORKER_MAXIMUM_MEMORY' -ParameterValue "${WorkerMaximumMemoryMB}m"

}

# Use a license that is managed online.
If (-not $Env:MLMLicenseFile) {
    Edit-MJSDef -ParameterName 'USE_ONLINE_LICENSING' -ParameterValue 'true'
}

# Set up MJS Cluster for Auto-Resizing
# https://www.mathworks.com/help/matlab-parallel-server/set-up-your-mjs-cluster-for-resizing.html
If (($Env:NodeType -eq 'headnode') -and ($Env:EnableAutoscaling -eq 'Yes')) {
    If ($Env:MATLABRelease -ge 'R2022a') {
        Edit-MJSDef -ParameterName 'MAX_WINDOWS_WORKERS' -ParameterValue "$(1*$Env:MaxNodes*$Env:WorkersPerNode)"

        # Create Task Scheduler task
        $TaskName = 'Autoscaling Task for MATLAB Parallel Server'
        schtasks /query /tn $TaskName
        If ($LastExitCode -eq 0) {
            Write-Output 'Autoscaling task already exists'
        } Else {
            Write-Output 'Creating autoscaling task'
            $TaskCommand = "cmd /c '$Env:ProgramFiles\MathWorks\autoscaling\autoscaling.py'"
            $PeriodInMinutes = 1
            schtasks /create /tn $TaskName /sc minute /mo $PeriodInMinutes /tr $TaskCommand /ru System
        }
    } Else {
        Write-Output 'WARNING: Auto-Resizing is only available for R2022a and later'
    }
}

# Set scheduling algorithm for the job manager
If ($Env:SchedulingAlgorithm) {
    If ($Env:MATLABRelease -gt 'R2023a') {
        Edit-MJSDef -ParameterName 'SCHEDULING_ALGORITHM' -ParameterValue "$Env:SchedulingAlgorithm"
    } Else {
        Write-Output 'WARNING: Selecting the scheduling algorithm is only available for R2023b and later'
    }
}
