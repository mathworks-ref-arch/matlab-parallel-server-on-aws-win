# Copyright 2022-2026 The MathWorks, Inc.
# This file is sourced by powershell at launch of the EC2 instance in user data.
# It defines all the environment variables required to startup properly.

# Obtain IMDSv2 session token
$IMDSToken = Invoke-RestMethod `
    -Method PUT `
    -Uri 'http://169.254.169.254/latest/api/token' `
    -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '21600' }

$IMDSHeaders = @{ 'X-aws-ec2-metadata-token' = $IMDSToken }

$Env:MATLABRoot = (Get-Item (Get-Command matlab).Path).Directory.Parent.FullName
$Env:PolyspaceRoot = $Env:MATLABRoot -replace 'MATLAB','Polyspace'

$Env:MATLABRelease = ([xml](Get-Content "$Env:MATLABRoot\VersionInfo.xml")).MathWorks_version_info.release

$Env:MJSBinDirectory = "$Env:MATLABRoot\toolbox\parallel\bin"
$Env:MJSDefFile = "$Env:MJSBinDirectory\mjs_def.bat"

$Env:EbsVolume = Invoke-RestMethod `
    -Uri 'http://169.254.169.254/latest/meta-data/block-device-mapping/ebs1' `
    -Headers $IMDSHeaders
If ($Env:EbsVolume) {
    $Env:CheckpointRoot = 'D:\MJS\Checkpoint'
} Else {
    $Env:CheckpointRoot = "$Env:ProgramData\MJS\Checkpoint"
}

$Env:SecurityRoot = "$Env:CheckpointRoot\security"
$Env:SecretFile = "$Env:SecurityRoot\secret"
$Env:CertFile = "$Env:SecurityRoot\cert"
$Env:MJSAdminPasswordFile = "$Env:SecurityRoot\initial_admin_password"

$Env:LocalHostname = Invoke-RestMethod `
    -Uri 'http://169.254.169.254/latest/meta-data/local-hostname' `
    -Headers $IMDSHeaders
$Env:DnsSearchSuffix = $Env:LocalHostname.Substring($Env:LocalHostname.IndexOf('.') + 1)

$Env:LocalIPv4 = Invoke-RestMethod `
    -Uri 'http://169.254.169.254/latest/meta-data/local-ipv4' `
    -Headers $IMDSHeaders

# public-hostname returns 404 when the instance has no public IP, treat it as empty
try {
    $Env:PublicHostname = Invoke-RestMethod `
        -Uri 'http://169.254.169.254/latest/meta-data/public-hostname' `
        -Headers $IMDSHeaders `
        -ErrorAction Stop
} catch {
    $Env:PublicHostname = ''
}
