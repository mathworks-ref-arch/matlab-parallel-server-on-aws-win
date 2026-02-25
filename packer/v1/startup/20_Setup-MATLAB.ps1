# Copyright 2022-2023 The MathWorks, Inc.

If ($Env:MATLABRoot -and ($Env:MLMLicenseFile -match '\d+@.+')) {
    Write-Output 'License MATLAB using Network License Manager'
    $OnlineLicensePath = "$Env:MATLABRoot\licenses\license_info.xml"
    If (Test-Path $OnlineLicensePath) { Remove-Item $OnlineLicensePath }

    $Port, $Hostname = $Env:MLMLicenseFile.split('@')
    $LicenseContent = "SERVER $Hostname 123456789ABC $Port`r`nUSE_SERVER"
    $LicenseRoot = "$Env:MATLABRoot\licenses"
    If (-not (Test-Path $LicenseRoot)) { New-Item -Path $LicenseRoot -ItemType Directory }
    Set-Content -Path "$LicenseRoot\network.lic" -Value $LicenseContent -NoNewline
} Else {
    Write-Output 'License MATLAB using Online Licensing'
}
