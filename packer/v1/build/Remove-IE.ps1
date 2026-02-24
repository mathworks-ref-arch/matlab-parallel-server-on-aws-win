# Copyright 2024-2026 The MathWorks, Inc.

# Removes Internet Explorer

# Set to exit on any error. Treat nonterminating errors as terminating errors.
$ErrorActionPreference = "Stop"

"Remove Internet Explorer"
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online -NoRestart
# If IE is not present still returns success

# Add a registry entry to fix an issue when running "Invoke-WebRequest" from Optional Inline Command.
$KeyPath = 'Registry::HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Internet Explorer\Main'
if (!(Test-Path $KeyPath)) { New-Item $KeyPath -Force | Out-Null }
Set-ItemProperty -Path $KeyPath -Name "DisableFirstRunCustomize" -Value 1
