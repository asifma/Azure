Param(
  [Parameter(Mandatory)]
  [string] $TeamAccount,
  [string] $PoolName = "default",
  [Parameter(Mandatory)]
  [string] $PATToken
)

$newdisk = @(get-disk | Where-Object partitionstyle -eq 'raw')
$Labels = @('agentdisk','Backup','Data','System','Logs')
