# Copyright 2023-2024 The MathWorks, Inc.

# Set to exit on any error. Treat nonterminating errors as terminating errors.
$ErrorActionPreference = "Stop"

"Generate Toolbox cache xml if MATLAB version is greater than or equal to 2021b"
# Toolbox cache generation is supported from R2021b onwards.
if ("$env:RELEASE" -ge "R2021b") {
    & "C:\Program Files\Python310\python.exe" C:\Windows\Temp\config\matlab\generate_toolbox_cache.py "C:\Program Files\MATLAB\$env:RELEASE" "C:\Program Files\MATLAB\$env:RELEASE\toolbox\local"
}
else{
   Write-Host "Unable to generate Toolbox cache xml as version $env:RELEASE is less than R2021b"
}
