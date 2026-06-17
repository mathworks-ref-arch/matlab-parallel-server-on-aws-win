#!/usr/bin/env python3

# Copyright 2022-2026 The MathWorks, Inc.

import logging

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface


logger = logging.getLogger('mw.autoscaling.scale_in_protection')

STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Execute scale-in protection routine.

    The routine unprotects idle nodes if the desired capacity is lower than the
    current capacity. A node is idle if all of its workers have been idle for
    more than the idle timeout.

    Args:
        cloud_interface (CloudInterface): Cloud provider specific
        implementation of AbstractCloudInterface.
        os_interface (OSInterface): Operating system specific implementation
        of AbstractOSInterface.

    Returns:
        status (int): Status code of program.
                        0: Successful
                        1: Faced an issue with cloud provider
                        2: Faced an issue with cluster
                        3: Faced an issue with both
    """
    cloud_capacity = cloud_interface.get_cloud_capacity()
    if cloud_capacity is None:
        logger.error('There was an issue retrieving cloud capacities, exiting.')
        return STATUS_CLOUD_ISSUE

    logger.info('Current cloud capacities: %s', cloud_capacity)

    node_difference = (cloud_capacity.current_nodes
                       - cloud_capacity.desired_nodes)

    cluster_issue, cloud_issue = False, False
    if node_difference == 0:
        logger.info('The desired capacity matches the current capacity')

    elif node_difference < 0:
        logger.info('The desired capacity is higher than the current capacity')

    elif node_difference > 0:
        logger.info('The desired capacity is lower than the current capacity by '
                    '%d nodes', node_difference)

        idle_timeout_seconds = cloud_interface.get_idle_timeout_seconds()
        logger.info('Idle timeout is %ds', idle_timeout_seconds)

        nodes_seconds_idle = os_interface.get_nodes_idle_time_seconds()

        nodes_to_stop = set()
        for node, seconds_idle in nodes_seconds_idle.items():
            logger.debug('- %s: %ds idle', node, seconds_idle)
            if seconds_idle > idle_timeout_seconds:
                logger.debug('  pick: %s', node)
                nodes_to_stop.add(node)
                if len(nodes_to_stop) >= node_difference:
                    break

            else:
                logger.debug('  skip: %s', node)

        if nodes_to_stop:
            nodes_stopped = os_interface.stop_workers_on_nodes(nodes_to_stop)
            if nodes_to_stop != nodes_stopped:
                failed_nodes = nodes_to_stop - nodes_stopped
                logger.warning('Failed to stop workers on %d nodes: %s',
                               len(failed_nodes), failed_nodes)
                cluster_issue = True

            if nodes_stopped:
                logger.info('Stopped workers on %d nodes', len(nodes_stopped))

                nodes_unprotected = cloud_interface.set_nodes_protection(
                    nodes_stopped, False)
                if nodes_stopped != nodes_unprotected:
                    failed_nodes = nodes_stopped - nodes_unprotected
                    logger.warning('Failed to unprotect %d nodes: %s',
                                   len(failed_nodes), failed_nodes)
                    cloud_issue = True

                if nodes_unprotected:
                    logger.info('Unprotected %d nodes', len(nodes_unprotected))

        else:
            logger.info('No nodes to stop')

    if cloud_issue and cluster_issue:
        return STATUS_CLOUD_AND_CLUSTER_ISSUE
    elif cloud_issue:
        return STATUS_CLOUD_ISSUE
    elif cluster_issue:
        return STATUS_CLUSTER_ISSUE
    else:
        return STATUS_SUCCESS
