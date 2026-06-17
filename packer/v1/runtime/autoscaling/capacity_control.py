#!/usr/bin/env python3

# Copyright 2021-2026 The MathWorks, Inc.

from mwplatforminterfaces import CloudInterface
from mwplatforminterfaces import OSInterface

import logging
from math import ceil


logger = logging.getLogger('mw.autoscaling.capacity_control')

STATUS_SUCCESS = 0
STATUS_CLOUD_ISSUE = 1
STATUS_CLUSTER_ISSUE = 2
STATUS_CLOUD_AND_CLUSTER_ISSUE = 3


def main(cloud_interface: CloudInterface, os_interface: OSInterface) -> int:
    """Execute capacity control routine.

    The routine adjusts the capacities so that they match:
        - The cluster's maximum number of workers changes depending on
          the cloud-computing platform's maximum number of nodes.
        - The cloud's desired number of nodes changes depending on the
          cluster's desired number of workers.

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

    cluster_capacity = os_interface.get_cluster_capacity()
    if cluster_capacity is None:
        logger.error('There was an issue retrieving cluster capacities, exiting.')
        return STATUS_CLUSTER_ISSUE

    logger.info('Current cluster capacities: %s', cluster_capacity)

    maximum_workers_requested = get_worker_count_from_nodes(
        cloud_capacity.maximum_nodes,
        cloud_capacity.workers_per_node
    )
    logger.info('Maximum: %d nodes -> %d workers',
                cloud_capacity.maximum_nodes, maximum_workers_requested)
    cluster_issue = False
    if maximum_workers_requested != cluster_capacity.maximum_workers:
        cluster_capacity_was_set = os_interface.set_cluster_capacity(
            maximum_workers_requested
        )
        if cluster_capacity_was_set:
            logger.info('Updated the cluster\'s maximum capacity')
        else:
            logger.warning('Failed to update the cluster\'s maximum capacity')
            cluster_issue = True

    desired_nodes_requested = get_node_count_from_workers(
        cluster_capacity.desired_workers,
        cloud_capacity.workers_per_node,
        cloud_capacity.minimum_nodes,
        cloud_capacity.maximum_nodes
    )
    logger.info('Desired: %d workers -> %d nodes',
                cluster_capacity.desired_workers, desired_nodes_requested)
    cloud_issue = False

    if desired_nodes_requested != cloud_capacity.desired_nodes:
        cloud_capacity_was_set = cloud_interface.set_cloud_capacity(
            desired_nodes_requested
        )
        if cloud_capacity_was_set:
            logger.info('Updated the cloud platform\'s desired capacity')
        else:
            logger.warning('Failed to update the cloud platform\'s desired capacity')
            cloud_issue = True
    else:
        logger.info("Requested capacity: %d nodes matches the cloud platform's "
                    "current desired capacity", desired_nodes_requested)

    if cloud_issue and cluster_issue:
        return STATUS_CLOUD_AND_CLUSTER_ISSUE
    elif cloud_issue:
        return STATUS_CLOUD_ISSUE
    elif cluster_issue:
        return STATUS_CLUSTER_ISSUE
    else:
        return STATUS_SUCCESS


def get_worker_count_from_nodes(nodes: int,
                                workers_per_node: int) -> int:
    return nodes * workers_per_node


def get_node_count_from_workers(workers: int,
                                workers_per_node: int,
                                minimum_nodes: int,
                                maximum_nodes: int) -> int:
    # Requesting the lowest number of nodes required to contain
    # the desired number of workers
    nodes = ceil(workers / workers_per_node)
    # Making sure we do not ask for more nodes than the maximum
    nodes = min(maximum_nodes, nodes)
    # Making sure we do not ask for fewer nodes than the minimum
    nodes = max(minimum_nodes, nodes)
    return nodes
