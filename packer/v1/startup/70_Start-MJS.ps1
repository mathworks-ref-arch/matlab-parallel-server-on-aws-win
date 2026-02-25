# Copyright 2022-2026 The MathWorks, Inc.

Write-Output '===Setting up Networking==='

# Set context for Online Licensing.
[Environment]::SetEnvironmentVariable('MHLM_CONTEXT', 'MATLAB_PARALLEL_SERVER_AWS_WIN', 'Machine')

# Open all firewall ports. Rely on external network security group to protect subnet.
Get-NetFirewallRule | Where-Object {$_.Name -like "RemoteSvcAdmin*"} | Enable-NetFirewallRule
New-NetFirewallRule -Name "parallelserver_inbound" -DisplayName "parallelserver_inbound" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue
New-NetFirewallRule -Name "parallelserver_outbound" -DisplayName "parallelserver_outbound" -Direction Outbound -Action Allow -Protocol TCP -LocalPort 0-65535 -ErrorAction SilentlyContinue

# Ensure that all communication with the headnode occurs on the local network.
If ($Env:NodeType -eq 'headnode') {
    Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:LocalIPv4`t$Env:PublicHostname"
} Else {
    Add-Content "$Env:Windir\System32\drivers\etc\hosts" "$Env:HeadnodeLocalIP`t$Env:HeadnodeHostname"
}

# Ensure that the MATLAB client can connect directly to the workers. 
# This is a necessary condition to create parpools.
[Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_EXTERNAL_HOSTNAME', $Env:PublicHostname, 'Machine')
[Environment]::SetEnvironmentVariable('MDCE_OVERRIDE_INTERNAL_HOSTNAME', $Env:LocalHostname, 'Machine')

# Configure MPI to use correct identifiers.
[Environment]::SetEnvironmentVariable('MPICH_INTERFACE_HOSTNAME', $Env:LocalHostname, 'Machine')
[Environment]::SetEnvironmentVariable('MSMPI_ACCEPT_HOST', $Env:LocalIPv4, 'Machine')

If ($Env:NodeType -eq 'headnode') {
    # Hostname of the job manager.
    $MJSHostname = $Env:PublicHostname
} Else {
    # Hostname of the worker node
    $MJSHostname = $Env:LocalHostname
}

$MJSOpts = @(
    '-hostname', $MJSHostname,
    '-loglevel', '2',
    '-enablepeerlookup',
    '-sharedsecretfile', $Env:SecretFile,
    '-cleanPreserveJobs',
    '-disableelevate'
)

Set-Location "$Env:MJSBinDirectory"

# Stop MJS if it is already running
If ($Env:NodeType -eq 'headnode') {
    $mjsRunning = (tasklist /fi "ImageName eq mjsd.exe" | Select-String -Pattern "mjsd.exe" -Quiet)

    if ($mjsRunning) {
        Write-Output "MJS is running, hence stopping already running services."
        .\stopjobmanager.bat -name "$Env:JobManagerName" -cleanPreserveJobs
        Write-Output "Stopped Job manager"
        .\mjs.bat stop -cleanPreserveJobs
    }

    .\mjs.bat uninstall -cleanPreserveJobs
    If (-not $?) {
        Write-Output 'Failed to uninstall MJS, must not be installed'
    }
}

# Start all services

Write-Output '===Installing MATLAB Job Scheduler==='
.\mjs.bat install -cleanPreserveJobs
If (-not $?) {Throw 'Failed to install MJS'}

Write-Output '===Starting MATLAB Job Scheduler==='
.\mjs.bat start $MJSOpts
If (-not $?) {Throw "Failed to start MJS with options: $MJSOpts"}

If ($Env:NodeType -eq 'headnode') {
    Write-Output '===Starting Job Manager==='
    If (Test-Path $Env:MJSAdminPasswordFile) {
        # Provide the password for the administrator account if one has been generated (Security Level 2 and 3)
        $AdminPassword = $(Get-Content $Env:MJSAdminPasswordFile)
        If ( $Env:MatlabRelease -ge 'R2024a' ) {
            $Env:PARALLEL_SERVER_JOBMANAGER_ADMIN_PASSWORD = $AdminPassword
        } Else {
            $Env:MDCEQE_JOBMANAGER_ADMIN_PASSWORD = $AdminPassword
        }
    }
    .\startjobmanager.bat -name "$Env:JobManagerName" -certificate "$Env:CertFile" -cleanPreserveJobs

} Else {
    Write-Output '===Starting workers==='
    .\startworker.bat -jobmanagerhost $Env:HeadnodeHostname -jobmanager "$Env:JobManagerName" -num $Env:WorkersPerNode
}
