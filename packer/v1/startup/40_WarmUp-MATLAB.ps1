# Copyright 2022-2023 The MathWorks, Inc.

If ($Env:MATLABRoot) {
    & "$Env:MATLABRoot\bin\win64\MATLABStartupAccelerator.exe" 64 "$Env:MATLABRoot" "$Env:ProgramData\MathWorks\msa.ini" "$Env:ProgramData\MathWorks\msa.log"
}
