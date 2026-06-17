# Copyright 2026 The MathWorks, Inc.
# This script configures the hostnames used by headnode and workers for
# client-cluster (ExternalHostname) and intra-cluster (InternalHostname) communication
# Sourced by powershell during user-data

# Initialize internal and external hostnames to be the local DNS name
$Env:InternalHostname = $Env:LocalHostname
$Env:ExternalHostname = $Env:LocalHostname

# Configure the external hostname of headnode that will be visible to workers.
# The HeadnodeHostname variable is set in the cloud formation template's
# user data section. It is available only in worker nodes' userdata environments
If ($Env:NodeType -eq 'worker') {
    $Env:HeadnodeExternalHostname = $Env:HeadnodeHostname
    If ($Env:CommunicationMode -eq 'PrivateDNS') {
        # When the communication mode is PrivateDNS, we must
        # ensure that we use the DNS search suffix returned by IMDS
        $Env:HeadnodeExternalHostname += ".$Env:DnsSearchSuffix"
    }
}

# Determine specific External/Internal Hostname overrides
If ($Env:PublicHostname) {
    # Public Cluster, default to using Public DNS name
    # for client communication for workers
    $Env:ExternalHostname = $Env:PublicHostname
} ElseIf (($Env:MATLABRelease -gt 'R2022b') -and ($Env:CommunicationMode -ne 'PrivateDNS')) {
    # Private Cluster (R2023a+) using IPs instead of DNS
    $Env:ExternalHostname = $Env:LocalIPv4
    $Env:InternalHostname = $Env:LocalIPv4
}
