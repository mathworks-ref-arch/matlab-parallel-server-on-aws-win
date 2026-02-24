# Copyright 2024-2026 The MathWorks, Inc.

# Installs NVIDIA GRID and GPU Drivers.
# Downloads them from nvidia directly.  Version may need to change between MATLAB releases.
# Must be run on a GPU Instance type (e.g. p2.xlarge)

# Set to exit on any error. Treat nonterminating errors as terminating errors.
$ErrorActionPreference = "Stop"

# Start GPU driver install in the temp folder
Set-Location C:\Windows\Temp

$start_time = Get-Date

# Download the drivers
Write-Output "Downloading Drivers"
$output="C:\Windows\Temp\cuda.exe"

(New-Object System.Net.WebClient).DownloadFile($env:NVIDIA_DRIVER_INSTALLER_URL, $output)

Write-Output "Time taken: $((Get-Date).Subtract($start_time).Seconds) second(s)"

# Install drivers - the instance should be rebooted prior to use
Write-Output "Installing Drivers"
Start-Process -FilePath "C:\Windows\Temp\cuda.exe" -ArgumentList "-s -noreboot -clean" -Wait -NoNewWindow
if ($LastExitCode -ne 0) {
    exit $LastExitCode
}
# ----- Sleep to allow the setup program to finish. -----
"Waiting on drivers to complete"
Start-Sleep -Seconds 240

Write-Output "Done Installing drivers"
