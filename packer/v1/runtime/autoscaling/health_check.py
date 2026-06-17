#!/usr/bin/env python3

# Copyright 2022-2026 The MathWorks, Inc.

import logging

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface


logger = logging.getLogger('mw.autoscaling.health_check')

STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
HEALTH_CHECK_GRACE_PERIOD_SECONDS = 600


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Evaluate orphaned nodes in the cluster.

    This routine looks for nodes that have been running for atleast 
    idle_timeout_seconds and are not registered with MJS or are in a suspended state. 
    These could be unhealthy nodes that are orphaned from MJS due to unexpected 
    reasons (user data execution failure, etc.).

    The routine will try to set their health status as Unhealthy. The cloud platform will
    then automatically replace the nodes with new ones to match the desired capacity.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
    """
    idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()

    # We must wait for at least HEALTH_CHECK_GRACE_PERIOD_SECONDS before evaluate
    # health of the worker nodes
    health_check_grace_period = max(HEALTH_CHECK_GRACE_PERIOD_SECONDS, idle_timeout_seconds)
    print(f"Health check grace period is {health_check_grace_period}s")

    current_nodes = cloud_interface.get_worker_nodes(
        grace_period_seconds=health_check_grace_period
    )

    if not current_nodes:
        logger.info("There are no worker nodes running for more than %d seconds.",
                    health_check_grace_period)
        return STATUS_SUCCESS

    logger.info("%d nodes running for more than %d seconds: %s",
                len(current_nodes), health_check_grace_period, current_nodes)

    suspended_nodes = os_interface.get_suspended_nodes(current_nodes)
    logger.info("%d suspended nodes: %s", len(suspended_nodes), suspended_nodes)

    registered_worker_nodes = os_interface.get_worker_nodes()
    current_unregistered_nodes = current_nodes - registered_worker_nodes
    logger.info("%d unregistered nodes: %s",
                len(current_unregistered_nodes), current_unregistered_nodes)

    nodes_to_mark_unhealthy = suspended_nodes.union(current_unregistered_nodes)

    if not nodes_to_mark_unhealthy:
        logger.info("All nodes are healthy")
        return STATUS_SUCCESS

    logger.warning("Marking suspended and unregistered nodes as unhealthy: %s",
                   nodes_to_mark_unhealthy)
    nodes_were_marked = cloud_interface.set_nodes_unhealthy(nodes_to_mark_unhealthy)

    if not nodes_were_marked:
        logger.error("Failed to mark nodes as unhealthy")
        return STATUS_CLOUD_ISSUE

    return STATUS_SUCCESS
