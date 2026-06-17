#!/usr/bin/env python3

# Copyright 2022-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

import capacity_control
import health_check
import scale_in_protection

import argparse
from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
import sys


logger = logging.getLogger('mw.autoscaling')

STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3


def parse_args(args=None):
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description='Execute autoscaling routine.')
    parser.add_argument(
        '--use-private-ip-mapping',
        type=lambda x: x.lower() == 'true',
        default=False,
        help='Use private IP addresses for hostname mapping (True/False).'
    )
    parser.add_argument(
        '--dns-search-suffix',
        type=str,
        default='',
        help='DNS search suffix to append to worker hostnames.'
    )
    return parser.parse_args(args)


def main(use_private_ip_mapping: bool = False, dns_search_suffix: str = '') -> int:
    """Execute autoscaling routine.

    The routine has three stages:
        1. Capacity control: Update the cloud platform's desired capacity and
           MJS max capacity.
        2. Health check: Identifies nodes in an unhealthy state and requests
           their termination.
        3. Scale-in protection: Ensures that we do not terminate nodes with
           ongoing work.

    Args:
        use_private_ip_mapping (bool): Use private IP addresses for node mapping.
        dns_search_suffix (str): DNS search suffix to append to hostnames.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    logger.info('Connecting to the cloud computing platform')
    cloud_interface = CloudInterface(
            dns_search_suffix=dns_search_suffix,
            use_private_ip_mapping=use_private_ip_mapping,
        )

    logger.info('Connecting to cluster')
    os_interface = OSInterface()

    logger.info('Starting capacity control')
    status_cc = capacity_control.main(cloud_interface, os_interface)
    logger.info('Finished capacity control: %s', status_cc)

    logger.info('Starting health check')
    status_hc = health_check.main(cloud_interface, os_interface)
    logger.info('Finished health check: %s', status_hc)

    logger.info('Starting scale-in protection')
    status_sp = scale_in_protection.main(cloud_interface, os_interface)
    logger.info('Finished scale-in protection: %s', status_sp)

    return max(status_cc, status_hc, status_sp)


if __name__ == '__main__':
    args = parse_args()

    log_file = 'C:\\ProgramData\\MathWorks\\autoscaling.log'
    log_handler = RotatingFileHandler(
        log_file, maxBytes=1_000_000, backupCount=5
    )
    log_formatter = logging.Formatter(
        '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    log_handler.setFormatter(log_formatter)

    root_logger = logging.getLogger('mw')
    root_logger.addHandler(log_handler)
    root_logger.setLevel(logging.DEBUG)

    logger.info('Starting autoscaling: %s', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
    status = main(
        use_private_ip_mapping=args.use_private_ip_mapping,
        dns_search_suffix=args.dns_search_suffix
    )
    logger.info('Finished autoscaling: %s', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))

    sys.exit(status)
