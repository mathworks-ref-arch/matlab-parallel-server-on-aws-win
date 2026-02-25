# Copyright 2024-2026 The MathWorks, Inc.

# Set to exit on any error. Treat nonterminating errors as terminating errors.
$ErrorActionPreference = "Stop"

Write-Output 'Starting Install AWS Cli ...'

Start-Process -FilePath MsiExec -ArgumentList '/i https://awscli.amazonaws.com/AWSCLIV2.msi /qn' -Wait
$Env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
aws --version

Write-Output 'Done with Install AWS Cli.'

Write-Output 'Starting Install-WindowsFeature'
# Install .Net 3.5 framework
Install-WindowsFeature Net-Framework-Core -source \\network\share\sxs
Write-Output 'Done with Install-WindowsFeature'

# Get Windows Server version number. ex: 2019, 2022 ...
$WindowsVersion = (Get-ComputerInfo).OsName
$VersionNumber = ($WindowsVersion -split '\s+')[3]

$VersionPattern = "^20[1-9][0-9]$"

if ($VersionNumber -notmatch $VersionPattern) {
    throw "Unsupported platform: $WindowsVersion"
}

# Download and install NVIDIA Grid Drivers
$Bucket = "ec2-windows-nvidia-drivers"
$KeyPrefix = "latest"
$LocalPath = "C:\Windows\Temp\NVIDIA"
$InstallerPath = ""
$Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
foreach ($Object in $Objects) {
    $LocalFileName = $Object.Key
    Write-Output "NVIDIA driver version : $LocalFileName"
    if ($LocalFileName -ne '' -and $Object.Size -ne 0 ) {
        $InstallerPath = Join-Path $LocalPath $LocalFileName
        Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $InstallerPath -Region us-east-1
        break
    }
}

# Throw error if no NVIDIA driver was found
if ($InstallerPath -eq '') {
    throw "No NVIDIA driver found for $WindowsVersion"
}

Start-Process "$InstallerPath" -ArgumentList "/s" -Wait

# Download DirectX runtime.
"Download directx installer"
(New-Object System.Net.WebClient).DownloadFile($env:MICROSOFT_DIRECTX_URL, 'C:\Windows\Temp\dxwebsetup.exe')

# Install driverx
Start-Process 'C:\Windows\Temp\dxwebsetup.exe' -ArgumentList "-q" -Wait

"Install Python"
Invoke-WebRequest -Uri $env:PYTHON_INSTALLER_URL -OutFile .\python.exe
Start-Process .\python.exe -Wait -ArgumentList '/quiet InstallAllUsers=1'
Remove-Item .\python.exe

## Download and install Edge browser
"Download and install Edge browser"
# Due to an issue for Global Mutex Lock, a sleep of 5 mins seems to be sufficient before installation of Edge.
# The global mutex lock issue is only appearing during packer build, but not reproducible when running manually.
# Microsoft Edge Download Page: https://www.microsoft.com/en-us/edge/business/download
Start-Sleep -s 300

(New-Object System.Net.WebClient).DownloadFile('https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/526e409c-5514-4dda-abdb-39df0afe9c9e/MicrosoftEdgeEnterpriseX64.msi', 'C:\Windows\Temp\MicrosoftEdgeEnterpriseX64.msi')

Start-Process msiexec.exe -Wait -ArgumentList '/i C:\Windows\Temp\MicrosoftEdgeEnterpriseX64.msi /quiet /norestart /l*v C:\Windows\Temp\edge_install_msi.log'

Write-Output 'Done with installing Edge browser'
