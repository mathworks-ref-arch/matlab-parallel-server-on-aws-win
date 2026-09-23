# Copyright 2025-2026 The MathWorks, Inc.
#
# EC2Launch v2 user_data: enable the OpenSSH server and set PowerShell as its default shell.
version: 1.1
tasks:
  - task: enableOpenSsh
  - task: executeScript
    inputs:
      - frequency: once
        type: powershell
        runAs: localSystem
        content: |-
          $ErrorActionPreference = 'Stop'
          $SSHRegPath = 'HKLM:\SOFTWARE\OpenSSH'
          if (-not (Test-Path $SSHRegPath)) { New-Item -Path $SSHRegPath -Force | Out-Null }
          New-ItemProperty -Path $SSHRegPath -Name DefaultShell -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force
