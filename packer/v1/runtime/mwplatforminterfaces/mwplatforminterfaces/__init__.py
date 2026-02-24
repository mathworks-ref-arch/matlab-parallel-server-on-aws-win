# Copyright 2021-2022 The MathWorks, Inc.

"""mwplatforminterfaces package

Contains classes to interact with other services.

Classes:
    cloud_interface.AbstractCloudInterface: Base class of the cloud interface.
        aws_interface.AWSInterface: AWS implementation of the cloud interface.
        azure_interface.AzureInterface: Azure implementation of the cloud
        interface.

    os_interface.AbstractOSInterface: Base class of the os interface.
        linux_interface.LinuxInterface: Linux implementation of the os
        interface.
        windows_interface.WindowsInterface: Windows implementation of the os
        interface.
"""

import platform

from .aws_interface import AWSInterface as CloudInterface

if platform.system() == 'Windows':
    from .windows_interface import WindowsInterface as OSInterface
else:
    from .linux_interface import LinuxInterface as OSInterface
