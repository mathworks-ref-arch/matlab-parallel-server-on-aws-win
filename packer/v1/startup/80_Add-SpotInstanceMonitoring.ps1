# Copyright 2022-2024 The MathWorks, Inc.

If (($Env:NodeType -eq 'worker') -And ($Env:UseSpotInstancesForWorkers -eq 'Yes')) {
    $TaskName = 'Handle Spot Worker command on EC2 Instance Interruption.'
    Write-Output 'Creating a task to monitor spot instance interruptions and stop all workers on the worker before EC2 termination.'
    $TaskCommand = "cmd /c '$Env:ProgramFiles\MathWorks\spotinstances\handle_instance_interruption.py'"
    $PeriodInMinutes = 1
    schtasks /create /tn $TaskName /sc minute /mo $PeriodInMinutes /tr $TaskCommand /ru System
}