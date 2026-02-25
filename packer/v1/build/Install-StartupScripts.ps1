# Copyright 2022-2024 The MathWorks, Inc.

# Create folder
if (-not (Test-Path "$Env:ProgramFiles\MathWorks")) {
    New-Item -Path "$Env:ProgramFiles" -Name 'MathWorks' -ItemType 'directory' | Out-Null
}

# Install Startup scripts
Move-Item -Path 'C:\Windows\Temp\startup\' -Destination "$Env:ProgramFiles\MathWorks\Startup"
