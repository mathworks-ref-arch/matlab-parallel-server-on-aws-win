# Copyright 2022-2023 The MathWorks, Inc.

If ($Env:PolyspaceRoot -and ($Env:MLMLicenseFile -match '\d+@.+')) {
    Write-Output 'License Polyspace using Network License Manager'
    $OnlineLicensePath = "$Env:PolyspaceRoot\licenses\license_info.xml"
    If (Test-Path $OnlineLicensePath) { Remove-Item $OnlineLicensePath }

    $Port, $Hostname = $Env:MLMLicenseFile.split('@')
    $LicenseContent = "SERVER $Hostname 123456789ABC $Port`r`nUSE_SERVER"
    $LicenseRoot = "$Env:PolyspaceRoot\licenses"
    If (-not (Test-Path $LicenseRoot)) { New-Item -Path $LicenseRoot -ItemType Directory }
    Set-Content -Path "$LicenseRoot\network.lic" -Value $LicenseContent -NoNewline
} Else {
    Write-Output 'License Polyspace using Online Licensing'
}
