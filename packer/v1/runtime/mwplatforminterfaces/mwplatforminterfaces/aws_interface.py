# Copyright 2021-2026 The MathWorks, Inc.

from .cloud_interface import (AbstractCloudInterface, CloudCapacity,
                              IDLE_TIMEOUT_TAG, IDLE_TIMEOUT_DEFAULT)

import boto3
from botocore.exceptions import ClientError
from datetime import datetime, timezone
import requests
import sys
from typing import Set


# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html
IMDS_URL = 'http://169.254.169.254'
# Time after launch before the node is considered fully running
GRACE_PERIOD_MINUTES = 5


class AWSInterface(AbstractCloudInterface):
    """Class to interact with Amazon's cloud computing platform.

    Attributes:
        session (boto3.Session): Session to access aws clients and resources.
        asg_client (AutoScaling.Client): Auto Scaling group client.
        asg_name (str): Auto Scaling group name (physical resource id).
        workers_per_node (int): Number of MATLAB workers per EC2 instance.
    """
    __session: boto3.Session

    __asg_client: None
    __asg_name: str

    _workers_per_node: int

    def __init__(self) -> None:
        """Create AWSInterface object and set all necessary attributes.

        Headnode information is retrieved from the instance meta-data url.
        Auto Scaling group is identified through its name in the
        CloudFormation outputs.
        """
        # Reading instance metadata.
        document = requests.get(
            f'{IMDS_URL}/latest/dynamic/instance-identity/document'
        ).json()

        # Setting all necessary attributes
        self.__session = boto3.Session(region_name=document['region'])
        self.__asg_client = self.__session.client('autoscaling')

        stack = self.__get_stack(document['instanceId'])
        self.__asg_name = self.__get_asg_name(stack.outputs)

        instance_type = self.__get_node_instance_type(stack.parameters)
        self._workers_per_node = self.__get_workers_per_node(
            stack.parameters, instance_type
        )

    def get_cloud_capacity(self) -> CloudCapacity:
        """Get the Amazon EC2 Auto Scaling group capacity info
        as well as the number of workers per node.

        Returns:
            info (CloudCapacity): Auto Scaling group limits.
        """
        asg_data = self._get_asg_description()
        if asg_data is not None:
            info = CloudCapacity(
                desired_nodes=asg_data['DesiredCapacity'],
                minimum_nodes=asg_data['MinSize'],
                maximum_nodes=asg_data['MaxSize'],
                current_nodes=sum(1
                                  for i in asg_data['Instances']
                                  if i['HealthStatus'] == 'Healthy'
                                  and i['LifecycleState'] in ('Pending',
                                                              'InService')),
                workers_per_node=self._workers_per_node
            )
            return info

        return None

    def get_idle_timeout_seconds(self) -> int:
        """Get the idle timeout specified on the Auto Scaling group.
        This timeout specifies the minimum idle time to consider a worker to be
        idle. It is stored in the tag 'mwIdleTimeoutMinutes'.

        Returns:
            timeout (int): Idle timeout in seconds.
        """
        asg_data = self._get_asg_description()
        if asg_data is not None:
            try:
                timeout_minutes = get_kv(asg_data['Tags'], 'Key', 'Value',
                                         IDLE_TIMEOUT_TAG)
                timeout_seconds = int(float(timeout_minutes) * 60)
                if timeout_seconds >= 0:
                    return timeout_seconds

                print(f'Value "{timeout_minutes}" is negative.',
                          file=sys.stderr)

            except StopIteration:
                print(f'Tag "{IDLE_TIMEOUT_TAG}" was not found.',
                      file=sys.stderr)

            except ValueError:
                print(f'Value "{timeout_minutes}" is not a number.',
                      file=sys.stderr)

            self.__reset_idle_timeout()

        return IDLE_TIMEOUT_DEFAULT * 60

    def get_worker_nodes(self, grace_period_seconds: int = 300) -> Set[str]:
        """Get the current worker nodes running in the Auto Scaling group.
        Only the nodes in a good state (online and healthy) will be
        returned.

        online=LifecycleState:InService
        healthy=HealthStatus:Healthy

        Returns:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
        """
        asg_data = self._get_asg_description()
        if asg_data is not None:
            # More information about instance lifecycle:
            # https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-lifecycle.html
            nodes_ids = [
                i['InstanceId']
                for i in asg_data['Instances']
                if i['LifecycleState'] == 'InService'
                and i['HealthStatus'] == 'Healthy'
                and i['ProtectedFromScaleIn']
            ]

            if len(nodes_ids) == 0:
                return set()

            ec2_client = self.__session.client('ec2')
            ec2_data = ec2_client.describe_instances(InstanceIds=nodes_ids)
            now = datetime.now(timezone.utc)
            host_uptime = {
                i['PrivateDnsName']: now - i['LaunchTime']
                for r in ec2_data['Reservations']
                for i in r['Instances']
            }

            nodes_hostnames = {
                host
                for host, uptime in host_uptime.items()
                if uptime.total_seconds() > grace_period_seconds
            }

            return nodes_hostnames

        return None

    def set_cloud_capacity(self, desired_nodes: int) -> bool:
        """Update the Amazon EC2 Auto Scaling group desired capacity.
        The Auto Scaling group will then launch/stop as many instances
        as needed to reach the desired capacity.

        Args:
            desired_nodes (int): Desired number of Auto Scaling instances.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        try:
            self.__asg_client.set_desired_capacity(
                AutoScalingGroupName=self.__asg_name,
                DesiredCapacity=desired_nodes,
                HonorCooldown=False
            )

        except ClientError as e:
            print(e, file=sys.stderr)
            return False

        return True

    def set_nodes_unhealthy(self, nodes_hostnames: Set[str]) -> bool:
        """Indicate to Auto Scaling group that multiple nodes are no
        longer healthy. The Auto Scaling group will terminate the nodes
        shortly.

        Not healthy=HealthStatus:Unhealthy

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes to mark.

        Returns:
            status (bool): Exit status of the process.
            True indicates that it ran successfully.
        """
        status = True

        host_to_id = self._get_host_to_id()
        for hostname in nodes_hostnames:
            if hostname in host_to_id:
                id = host_to_id[hostname]
                try:
                    self.__asg_client.set_instance_health(
                        InstanceId=id,
                        HealthStatus='Unhealthy'
                    )

                except ClientError as e:
                    print(e, file=sys.stderr)
                    status = False

            else:
                print(f'Unknown hostname {hostname}', file=sys.stderr)
                status = False

        return status

    def set_nodes_protection(self, nodes_hostnames: Set[str], protect: bool) \
            -> Set[str]:
        """Update multiple nodes' protection status. When a node is protected,
        the Auto Scaling group cannot terminate it automatically.

        Args:
            nodes_hostnames (Set[str]): Hostnames of the nodes.
            protect (bool): Protection state to set.

        Returns:
            nodes_success (Set[str]): Hostnames of the nodes for which the
            operation was successful.
        """
        nodes_success = set()

        host_to_id = self._get_host_to_id()
        id_to_host = {i: h for h, i in host_to_id.items()}
        nodes_ids = list(filter(None, map(host_to_id.get, nodes_hostnames)))

        AWS_ID_LIMIT = 50
        for i in range(0, len(nodes_ids), AWS_ID_LIMIT):
            ids_slice = nodes_ids[i:i+AWS_ID_LIMIT]
            try:
                self.__asg_client.set_instance_protection(
                    AutoScalingGroupName=self.__asg_name,
                    InstanceIds=ids_slice,
                    ProtectedFromScaleIn=protect
                )
                nodes_success.update(map(id_to_host.get, ids_slice))

            except ClientError as e:
                print(e, file=sys.stderr)

        return nodes_success

    @staticmethod
    def is_spot_instance_marked_for_removal() -> bool:
        """Checks whether the Spot instance node will be removed by AWS.
        Achieves this by retrieving the status from EC2 metadata.

        Returns:
            True: When the Spot instance is identified by the cloud provider
            to be removed.
            False: When the Spot instance is not marked for removal
            by the cloud provider.
        """
        spot_instance_action = None
        try:
            spot_instance_action = requests.head(
             f'{IMDS_URL}/latest/meta-data/spot/instance-action'
            )
        except requests.ConnectionError:
            return False

        if spot_instance_action is None:
            return False

        return spot_instance_action.status_code == 200

    def _get_asg_description(self) -> dict:
        """Get the Auto Scaling group description.

        Returns:
            data (dict): Auto Scaling group description.
        """
        try:
            asg_response = self.__asg_client.describe_auto_scaling_groups(
                AutoScalingGroupNames=[self.__asg_name]
            )

            return asg_response['AutoScalingGroups'].pop()

        except (ClientError, IndexError, KeyError) as e:
            print(e, file=sys.stderr)

        return None

    def _get_host_to_id(self) -> dict:
        """Get a mapping between instances private hostname and their id.

        Returns:
            host_to_id (dict): Hostname to instance id dictionary.
        """
        host_to_id = {}

        asg_data = self._get_asg_description()
        if asg_data:
            nodes_ids = [i['InstanceId'] for i in asg_data['Instances']]

            ec2_client = self.__session.client('ec2')
            ec2_data = ec2_client.describe_instances(InstanceIds=nodes_ids)
            host_to_id = {
                i['PrivateDnsName']: i['InstanceId']
                for r in ec2_data['Reservations']
                for i in r['Instances']
            }

        return host_to_id

    def __get_asg_name(self, outputs) -> str:
        """Get the AutoScalingGroup name from the stack outputs."""
        return get_kv(outputs,
                      'OutputKey',
                      'OutputValue',
                      'ASGName')

    def __get_node_instance_type(self, parameters) -> str:
        """Get node instance type from the stack parameters."""
        return get_kv(parameters,
                      'ParameterKey',
                      'ParameterValue',
                      'WorkerInstanceType')

    def __get_stack(self, headnode_id: str) -> None:
        """Get cloudformation stack using its name from tags in headnode."""
        ec2 = self.__session.resource('ec2')
        headnode = ec2.Instance(headnode_id)

        cloudformation = self.__session.resource('cloudformation')
        stack_name = get_kv(headnode.tags,
                            'Key',
                            'Value',
                            'aws:cloudformation:stack-name')
        return cloudformation.Stack(stack_name)

    def __get_workers_per_node(self, parameters, instance_type: str) -> int:
        """Get number of workers per node from the stack parameters."""
        workers_per_node = get_kv(parameters,
                                  'ParameterKey',
                                  'ParameterValue',
                                  'NumWorkersPerNode')

        if workers_per_node == 'auto':
            ec2 = self.__session.client('ec2')
            instance_type_info = ec2.describe_instance_types(
                InstanceTypes=[instance_type])
            node_info = instance_type_info['InstanceTypes'].pop()
            workers_per_node = node_info['VCpuInfo']['DefaultCores']

        return int(workers_per_node)

    def __reset_idle_timeout(self) -> None:
        """Reset the idle timeout with the default."""
        print(f'Resetting {IDLE_TIMEOUT_TAG} tag to default '
              f'{IDLE_TIMEOUT_DEFAULT}', file=sys.stderr)
        self.__asg_client.create_or_update_tags(
            Tags=[{'ResourceId': self.__asg_name,
                   'ResourceType': 'auto-scaling-group',
                   'Key': IDLE_TIMEOUT_TAG,
                   'Value': str(IDLE_TIMEOUT_DEFAULT),
                   'PropagateAtLaunch': False}]
        )


def get_kv(iterable, key, val, filt):
    """Helper function to retrieve a key,value pair in an iterable."""
    return next(x[val] for x in iterable if x[key] == filt)
