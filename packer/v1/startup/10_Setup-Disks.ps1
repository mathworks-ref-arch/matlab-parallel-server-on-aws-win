# Copyright 2022-2023 The MathWorks, Inc.

# Make EBS volumes available (including NVMe instance store volumes)
# https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ebs-using-volumes.html

Stop-Service -Name ShellHWDetection

# Mount EBS volumes first
Get-Disk |
    Where-Object PartitionStyle -eq 'raw' |
    Where-Object UniqueId -match '^(.*Amazon Elastic Block Store|vol).*$' |
    Initialize-Disk -PartitionStyle MBR -PassThru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "EBS" -Confirm:$false

# Then mount instance local storage
Get-Disk |
    Where-Object PartitionStyle -eq 'raw' |
    Initialize-Disk -PartitionStyle MBR -PassThru |
    New-Partition -AssignDriveLetter -UseMaximumSize |
    Format-Volume -FileSystem NTFS -NewFileSystemLabel "Data" -Confirm:$false

Start-Service -Name ShellHWDetection
