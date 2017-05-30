# Parameters
Param(
  [string]$server,
  [string]$user,
  [string]$password,
  [string]$type
)

# Exit codes
$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3

# Initializing PowerShell Environment
$bpKey = 'BaseProductKey'
$regKey = get-Item "HKLM:\Software\DataCore\Executive"
$strProductKey = $regKey.getValue($bpKey)
$regKey = get-Item "HKLM:\$strProductKey"
$installPath = $regKey.getValue('InstallPath')

if (!(get-module -name DataCore.Executive.Cmdlets)) {
    Import-Module "$installPath\DataCore.Executive.Cmdlets.dll" -ErrorAction:Stop -Warningaction:SilentlyContinue
}

# Connect to SANsymphony
function connect {
    $server = hostname
    if (!(Connect-DcsServer -Server $server)) { 
        Write-Host "Unable to connect Datacore server $server"
        exit $CRITICAL
    }
}

# Check Pool status
function check_pool {
    connect
    $pools = Get-DcsPool
    foreach ($pool in $pools) {
        if ($pool.PoolStatus -ne 'Running') {
            $err_pool += $pool.Alias+' is '+$pool.PoolStatus+', '
        }
    }
    if ($err_pool -eq $null) {
        Write-Host "Ok: All Pools are running"
        exit $OK
    }
    else {
        Write-Host "CRITICAL: "$err_pool
        exit $CRITICAL
    }
}

# Check Servers
function check_server {
    connect
    $dcservers = Get-DcsServer
    foreach ($dcserver in $dcservers) {
        if ($dcserver.State -ne 'Online') {
            $err_dc += $dcserver.HostName+' is '+$dcserver.State+', '
        }
        if ($dcserver.PowerState -ne 'ACOnline') {
            $war_dc += $dcserver.HostName+' power state is '+$dcserver.PowerState+', '
        }
    }
    if (($err_dc -eq $null) -and ($war_dc -eq $null)) {
        Write-Host "Ok: All Servers are running healthy"
        exit $OK
    }
    elseif ($err_dc -ne $null) {
        Write-Host "CRITICAL: "$err_dc+" "+$war_dc
        exit $CRITICAL
    } 
    else {
        Write-Host "WARNING: "$war_dc
        exit $WARNING
    }
}

# Check Virtual disks
function check_vdisk {
    connect
    $vdisks = Get-DcsVirtualDisk
    foreach ($vdisk in $vdisks) {
        if ($vdisk.DiskStatus -ne 'Online') {
            $err_vdisk += $vdisk.Alias+' virtual disk status is '+$vdisk.DiskStatus+', '
        }
    }
    if ($err_vdisk -eq $null) {
        Write-Host "Ok: All virtual disks are healthy"
        exit $OK
    }
    else {
        Write-Host "CRITICAL: "$err_vdisk
        exit $CRITICAL
    }
}

# Check Logical disks
function check_ldisk {
    connect
    $ldisks = Get-DcsLogicalDisk
    foreach ($ldisk in $ldisks) {
        if ($ldisk.DiskStatus -ne 'Online') {
            $err_ldisk += $ldisk.StorageName+' logical disk status is '+$ldisk.DiskStatus+', '
        }
    }
    if ($err_ldisk -eq $null) {
        Write-Host "Ok: All logical disks are healthy"
        exit $OK
    }
    else {
        Write-Host "CRITICAL: "$err_ldisk
        exit $CRITICAL
    }
}

# Check Ports
function check_port {
    connect
    #$ports = Get-DcsPort -Type iSCSI
    Write-Host "Not yet implemented"
    exit $UNKNOWN   
}

# Check Alerts
function check_alert {
    connect
    #$alerts = Get-DcsAlert
    Write-Host "Not yet implemented"
    exit $UNKNOWN   
}

# Check Health
function check_health {
    connect
    $state = @(“Healthy”,”Undefined”)
    $health = Get-DcsMonitor |? {$_.state -notin $state -and $_.Caption -notlike "Vim*"}
    if ($health -eq $null) {
        Write-Host "Ok: System is healthy"
        exit $OK
    }
    else {
        foreach ($issue in $health) {
            $err_health += $issue.ExtendedCaption+' is '+$issue.State+', '
        }
        Write-Host "CRITICAL: "$err_health
        exit $OK
    }
}

# Print usage
function print_usage {
    Write-Host ".\check_datacore_health.ps1 -server <server> -user <user> -password <password> -type <check_type>
        -s -server    : Set if plugin runs out of datacore server
        -u -user      : Set diferent user to run this script
        -p -password  : Password to use with the username
        -t -type      : Specify command type (pool, server, vdisk, ldisk, port, alert, health, help)"
}

switch ($type) {
    pool { check_pool }
    server { check_server}
    vdisk { check_vdisk }
    ldisk { check_ldisk }
    port { check_port }
    alert { check_alert }
    health { check_health }
    help { print_usage }
    default { print_usage }
}