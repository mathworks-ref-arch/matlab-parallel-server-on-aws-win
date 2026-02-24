# Copyright 2025 The MathWorks, Inc.

function Set-SupportPackageRoot {

    param(
        [Parameter(Mandatory = $true)]
        [string] $Release,

        [Parameter(Mandatory = $true)]
        [string] $Destination,

        [Parameter(Mandatory = $true)]
        [string] $MATLABRoot
    )
    # Ensure that the destination directory exists
    if (-not (Test-Path -Path $Destination)) {
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    }

    if ( $Release -gt "R2024b" ) {
        $SprootWriterPath = Join-Path -Path "${MATLABRoot}" -ChildPath "bin\win64\sprootsettingwriter.exe"
        New-Item -Path "${Destination}" -ItemType Directory -Force | Out-Null    
        & "${SprootWriterPath}" -matlabroot "$MATLABRoot" -sproot "${Destination}"
    } else {
        Set-Content -Path "$MATLABRoot\toolbox\local\supportpackagerootsetting.xml" -Value "<?xml version=`"1.0`" encoding=`"UTF-8`"?><SupportPackageRootSettings><Setting name=`"sproot`">$Destination</Setting></SupportPackageRootSettings>"
    }

}

try {
    $ErrorActionPreference = 'Stop'
    $DefaultSpkgRoot = "C:\ProgramData\MATLAB\SupportPackages\$Env:RELEASE"
    $MATLABRoot = "C:\Program Files\MATLAB\$Env:RELEASE"
    Set-SupportPackageRoot -Release $Env:RELEASE -Destination "${DefaultSpkgRoot}" -MATLABRoot "${MATLABRoot}"
}
catch {
    $ScriptPath = $MyInvocation.MyCommand.Path
    Write-Output "ERROR - An error occurred while running script 'Set-SupportPackageRoot': $ScriptPath. Error: $_"
    throw
}
