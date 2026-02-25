# Copyright 2022-2024 The MathWorks, Inc.

# Create folder
if (-not (Test-Path "$Env:ProgramFiles\MathWorks")) {
    New-Item -Path "$Env:ProgramFiles" -Name 'MathWorks' -ItemType 'directory' | Out-Null
}

# Install mwplatforminterfaces package
Move-Item -Path 'C:\Windows\Temp\runtime\mwplatforminterfaces\' -Destination "$Env:ProgramFiles\MathWorks\"
py -m pip install -e "$Env:ProgramFiles\MathWorks\mwplatforminterfaces"

# Install autoscaling package
Move-Item -Path 'C:\Windows\Temp\runtime\autoscaling\' -Destination "$Env:ProgramFiles\MathWorks\"

# Install spot instances package
Move-Item -Path 'C:\Windows\Temp\runtime\spotinstances\' -Destination "$Env:ProgramFiles\MathWorks\"
