#!/usr/bin/env python3

# Copyright 2022 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

import capacity_control
import health_check
import scale_in_protection

from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
import sys


STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3


def main() -> int:
    """Execute autoscaling routine.

    The routine has three stages:
        1. Capacity control: Update the cloud platform's desired capacity and
           MJS max capacity.
        2. Health check: Identifies nodes in an unhealthy state and requests
           their termination.
        3. Scale-in protection: Ensures that we do not terminate nodes with
           ongoing work.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    # Retrieving capacity information
    print('Connecting to the cloud computing platform')
    cloud_interface = CloudInterface()

    print('Connecting to cluster')
    os_interface = OSInterface()

    print('# Starting capacity control')
    status_cc = capacity_control.main(cloud_interface, os_interface)
    print(f'# Finished capacity control: {status_cc}')

    print('# Starting health check')
    status_hc = health_check.main(cloud_interface, os_interface)
    print(f'# Finished health check: {status_hc}')

    print('# Starting scale-in protection')
    status_sp = scale_in_protection.main(cloud_interface, os_interface)
    print(f'# Finished scale-in protection: {status_sp}')

    return max(status_cc, status_hc, status_sp)


if __name__ == '__main__':
    # Create logger
    logger = logging.getLogger('mw.autoscaling')
    log_file = 'C:\\ProgramData\\MathWorks\\autoscaling.log'
    log_handler = RotatingFileHandler(log_file, maxBytes=1e6, backupCount=5)
    log_handler.terminator = ''
    logger.addHandler(log_handler)
    logger.setLevel(logging.INFO)
    sys.stdout.write, sys.stderr.write = logger.info, logger.warning

    print(f'## Starting autoscaling: {datetime.now():%Y-%m-%d %H:%M:%S}')
    status = main()
    print(f'## Finished autoscaling: {datetime.now():%Y-%m-%d %H:%M:%S}\n')

    sys.exit(status)
