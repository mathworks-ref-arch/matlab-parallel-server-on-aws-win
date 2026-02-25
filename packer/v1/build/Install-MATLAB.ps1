<#
.SYNOPSIS
  Installs MATLAB, toolboxes, and Polyspace using MPM.

.NOTES
  Copyright 2023-2026 The MathWorks, Inc.
  The function sets $ErrorActionPreference to 'Stop' to ensure that any errors encountered during the installation process will cause the script to stop and throw an error.
#>

$ErrorActionPreference = "Stop"

function Install-MathWorksProductsUsingMPM {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $MATLABProducts,

        [Parameter(Mandatory = $false)]
        [string] $SourceURL
    )

    Write-Output 'Starting Install-MATLABUsingMPM...'
    Set-Location -Path $Env:TEMP

    $MpmLogFilePath = "$Env:TEMP\mathworks_$Env:USERNAME.log"
    Write-Output 'Installing products ...'
    $MATLABProductsList = $MATLABProducts -Split ' '

    $DocFlag = ""
    if ( $Release -lt 'R2023a' )
        {
            $DocFlag = "--doc"
        }

    try{
        if ( $SourceURL.length -eq 0 )
        {
            & "$Env:TEMP\mpm.exe" install `
            $DocFlag `
            --release $Release `
            --products $MATLABProductsList

            if ($LASTEXITCODE -ne 0) {
                throw "mpm.exe failed with exit code $LASTEXITCODE"
            }
        }
        else
        {            
            Mount-DataDrive -DriveToMount "$MATLABSourceDrive"
            Get-MATLABSourceFiles -SourceURL $SourceURL -Destination "$MATLABSourcePath"

            $SourcePath = Get-ChildItem -Path "$MATLABSourcePath" -Directory -Recurse -Filter 'archives' | Select-Object -First 1 -ExpandProperty FullName

            if (-not $SourcePath) {
                throw 'Failed to find MATLAB source files at the specified location'
            }

            & "$Env:TEMP\mpm.exe" install `
                --source=$SourcePath `
                --products $MATLABProductsList

            if ($LASTEXITCODE -ne 0) {
                throw "mpm.exe failed with exit code $LASTEXITCODE"
          }
        }
    }
    catch {
        if (Test-Path $MpmLogFilePath) {
            Get-Content -Path $MpmLogFilePath
        }
        throw
    }

    try { remove-item "$MpmLogFilePath" -erroraction stop }
    catch [System.Management.Automation.ItemNotFoundException] { $null }

    Write-Output 'Done with Install-MATLABUsingMPM.'
}

function Install-PolyspaceUsingMPM {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $PolyspaceProducts,

        [Parameter(Mandatory = $false)]
        [string] $SourceURL,

        [Parameter(Mandatory = $false)]
        [string] $PolyspaceRoot
    )
    Write-Output 'Starting Install-PolyspaceUsingMPM...'
    Set-Location -Path $Env:TEMP

    $MpmLogFilePath = "$Env:TEMP\mathworks_$Env:USERNAME.log"
    Write-Output 'Installing Polyspace products ...'
    
    if ( $PolyspaceRoot.length -ne 0 )
    {
        Set-Location -Path $PolyspaceRoot
    }
    else {
        $PolyspaceRoot = "$Env:ProgramFiles\Polyspace\$Env:RELEASE"
    }
    $PolyspaceProductsList = $PolyspaceProducts -Split ' '
    try{
        if ($SourceURL.Length -eq 0 ) 
        {
            & "$Env:TEMP\mpm.exe" install `
                --release $Release `
                --destination $PolyspaceRoot `
                --products $PolyspaceProductsList

            if ($LASTEXITCODE -ne 0) {
                throw "mpm.exe failed with exit code $LASTEXITCODE"
            }
        }
        else
        {
            # Use the already mounted extra volume drive containing MATLAB Support Packages source files
            $SourcePath = Get-ChildItem -Path "$MATLABSourcePath" -Directory -Recurse -Filter 'archives' | Select-Object -First 1 -ExpandProperty FullName

            & "$Env:TEMP\mpm.exe" install `
                --source=$SourcePath `
                --destination $PolyspaceRoot `
                --products $PolyspaceProductsList
            if ($LASTEXITCODE -ne 0) {
                throw "mpm.exe failed with exit code $LASTEXITCODE"
            }
        }
    }
    catch {
        if (Test-Path $MpmLogFilePath) {
            Get-Content -Path $MpmLogFilePath
        }
        throw
    }

    Set-Location -Path $Env:TEMP

    try { remove-item "$MpmLogFilePath" -erroraction stop }
    catch [System.Management.Automation.ItemNotFoundException] { $null }

    # Point MATLAB Parallel Server at polyspace install
    (Get-Content "C:\Program Files\MATLAB\$env:RELEASE\toolbox\parallel\bin\mjs_polyspace.conf") `
        -replace '# POLYSPACE_SERVER_ROOT=C:.+$', "POLYSPACE_SERVER_ROOT=$PolyspaceRoot" |
        Out-File -FilePath "C:\Program Files\MATLAB\$env:RELEASE\toolbox\parallel\bin\mjs_polyspace.conf" -Encoding ASCII

    Write-Output 'Done with Install-PolyspaceUsingMPM.'

}

function Setup-Components {
    Write-Output 'Starting Setup-Components ...'

    "Remove AWS EC2 desktop shortcuts"
    Remove-Item -path "C:\Users\Administrator\Desktop\*.website"

    # Check if the destination directory exists; if not, create it
    if (-not (Test-Path -Path "C:\ProgramData\MathWorks\msa.ini")) {
        New-Item -Path "C:\ProgramData\MathWorks\" -ItemType Directory | Out-Null
    }

    "Fetch msa.ini to speed up MATLAB startup"
    Invoke-WebRequest $Env:MSA_URL -OutFile "C:\ProgramData\MathWorks\msa.ini"

    "Set firewall rules for MATLAB"
    $env:RELEASE = $env:RELEASE.ToLower()

    New-NetFirewallRule -DisplayName "MATLAB $env:RELEASE" -Name "MATLAB $env:RELEASE" -Action Allow -Program "C:\program files\matlab\$env:RELEASE\bin\win64\matlab.exe"
    # mw_olm executable removed in R2023b
    New-NetFirewallRule -DisplayName "mw_olm" -Name "mw_olm" -Action Allow -Program "C:\program files\matlab\$env:RELEASE\bin\win64\mw_olm.exe"
    powershell -inputformat none -outputformat none -NonInteractive -Command "Add-MpPreference -ExclusionPath 'C:\Program Files\MATLAB'"

    "Set registry keys to disable pop-ups in Windows"
    New-Item -Path "HKLM:\System\CurrentControlSet\Control\Network\NewNetworkWindowOff\"

    Write-Output 'Done with Setup-Components.'
}

function Install-Certificates {
    Write-Output 'Starting Install-Certificates ...'

    "Install MathWorks SSL Certificate"
    function FetchAndInstall-Certs {
        param(
            [Parameter(Mandatory = $true)]
            [string] $url
        )
        $WebRequest = [Net.WebRequest]::CreateHttp($url)
        $WebRequest.AllowAutoRedirect = $true
        $Chain = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Chain
        [Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        # Request website
        try {$Response = $WebRequest.GetResponse()} catch {}
        # Creates Certificate
        $Certificate = $WebRequest.ServicePoint.Certificate.Handle
        # Build Chain
        $Chain.Build($Certificate)
        $Cert = $Chain.ChainElements[$Chain.ChainElements.Count-1].Certificate
        $bytes = $Cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        set-content -value $bytes -encoding byte -path "C:\Windows\Temp\mathworks_root_ca.cer"
        # Actually install the certificate
        Import-Certificate -FilePath "C:\Windows\Temp\mathworks_root_ca.cer" -CertStoreLocation "Cert:\LocalMachine\Root"
        # Cleanup
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $null
        Remove-Item "C:\Windows\Temp\mathworks_root_ca.cer"
    }
    # Always fetch and install production certificates
    FetchAndInstall-Certs("https://licensing.mathworks.com")

    Write-Output 'Done with Install-Certificates'
}

function Install-MPM {
    # As a best practice, installing the latest version of mpm before calling it.
    Write-Output 'Installing mpm ...'
    Invoke-WebRequest -OutFile "$Env:TEMP\mpm.exe" -Uri 'https://www.mathworks.com/mpm/win64/mpm'

}

function Remove-MPM {
    Write-Output 'Removing mpm ...'
    try { remove-item "$Env:TEMP\mpm.exe" -erroraction stop }
    catch [System.Management.Automation.ItemNotFoundException] { $null }
}

try {
    # Dot-source the utility script at the top level (script scope).
    # Its functions are now available to all other functions in this script.
    # We only do this if a source URL is provided, as the utils are only needed then.
    if ($Env:MATLAB_SOURCE_URL) {
        . 'C:\Windows\Temp\config\matlab\Mount-DataDriveUtils.ps1'
        $MATLABSourceDrive = 'X'
        $MATLABSourcePath = 'X:\matlab_source'
    }

    Setup-Components
    Install-Certificates
    Install-MPM
    Install-MathWorksProductsUsingMPM -Release $Env:RELEASE -MATLABProducts $Env:PRODUCTS -SourceURL $Env:MATLAB_SOURCE_URL
    Install-PolyspaceUsingMPM -Release $Env:RELEASE -PolyspaceProducts $Env:POLYSPACE_PRODUCTS -PolyspaceRoot $Env:POLYSPACE_ROOT -SourceURL $Env:MATLAB_SOURCE_URL
    Remove-MPM

    if ($Env:MATLAB_SOURCE_URL) {
        Dismount-DataDrive -DriveLetter "$MATLABSourceDrive"
    }
}
catch {
    Write-Output "ERROR - An error occurred: $_"
    throw
}
