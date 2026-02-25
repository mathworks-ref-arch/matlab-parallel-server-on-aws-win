# Copyright 2023 The MathWorks, Inc.

Write-Output "Optional user command - script started."

# Print the variable
Write-Output "$Env:OptionalUserCommand"

# Check whether the value of the parameter optional user command is empty.
if ([string]::IsNullOrWhiteSpace("$Env:OptionalUserCommand"))
{
    Write-Output "No optional user command was passed."
}
else
{
    Write-Output "The passed string is an inline PowerShell command."
    Invoke-Expression "$Env:OptionalUserCommand"
}

Write-Output "Optional user command - script completed."