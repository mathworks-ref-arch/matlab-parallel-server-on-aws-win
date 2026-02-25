# Copyright 2024-2026 The MathWorks, Inc.

# Run Sysprep

# Set to exit on any error. Treat nonterminating errors as terminating errors.
$ErrorActionPreference = "Stop"

$WindowsVersion = (Get-ComputerInfo).OsName

if ($WindowsVersion -eq "Microsoft Windows Server 2022 Datacenter") {
    # Ec2launch v2 for Windows Server 2022
    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2launch-v2-settings.html#ec2launch-v2-cli
    & "$env:ProgramFiles\Amazon\EC2Launch\ec2launch.exe" reset --clean
    & "$env:ProgramFiles\Amazon\EC2Launch\ec2launch.exe" sysprep --clean
}
elseif ($WindowsVersion -eq "Microsoft Windows Server 2019 Datacenter") {
    # Ec2launch v1 for Windows Server 2019
    & "$Env:ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1" -Schedule
    & "$Env:ProgramData\Amazon\EC2-Windows\Launch\Scripts\SysprepInstance.ps1" -NoShutdown
}
else {
    throw "Unsupported platform: $WindowsVersion"
}
