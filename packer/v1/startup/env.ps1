# Copyright 2022-2023 The MathWorks, Inc.
# This file is sourced by powershell at launch of the EC2 instance in user data.
# It defines all the environment variables required to startup properly.

$Env:MATLABRoot = (Get-Item (Get-Command matlab).Path).Directory.Parent.FullName
$Env:PolyspaceRoot = $Env:MATLABRoot -replace 'MATLAB','Polyspace'

$Env:MATLABRelease = ([xml](Get-Content "$Env:MATLABRoot\VersionInfo.xml")).MathWorks_version_info.release

$Env:MJSBinDirectory = "$Env:MATLABRoot\toolbox\parallel\bin" 
$Env:MJSDefFile = "$Env:MJSBinDirectory\mjs_def.bat"

$Env:EbsVolume = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/block-device-mapping/ebs1
If ($Env:EbsVolume) {
    $Env:CheckpointRoot = 'D:\MJS\Checkpoint'
} Else {
    $Env:CheckpointRoot = "$Env:ProgramData\MJS\Checkpoint"
}

$Env:SecurityRoot = "$Env:CheckpointRoot\security"
$Env:SecretFile = "$Env:SecurityRoot\secret"
$Env:CertFile = "$Env:SecurityRoot\cert"
$Env:MJSAdminPasswordFile = "$Env:SecurityRoot\initial_admin_password"

$Env:LocalHostname = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/local-hostname
$Env:LocalIPv4 = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/local-ipv4
$Env:PublicHostname = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/public-hostname
If (-not $Env:PublicHostname) {
    Write-Output 'This reference architecture requires public IP addresses.'
    Exit 1
}
