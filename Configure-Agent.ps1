Param(
  [Parameter(Mandatory)]
  [string] $TeamAccount,
  [string] $PoolName = "default",
  [Parameter(Mandatory)]
  [string] $PATToken
)

$newdisk = @(get-disk | Where-Object partitionstyle -eq 'raw')
$Labels = @('agentdisk','Backup','Data','System','Logs')

for($i = 0; $i -lt $newdisk.Count ; $i++)
{

    $disknum = $newdisk[$i].Number
    $dl = get-Disk $disknum | 
       Initialize-Disk -PartitionStyle GPT -PassThru | 
          New-Partition -AssignDriveLetter -UseMaximumSize
    Format-Volume -driveletter $dl.Driveletter -FileSystem NTFS -NewFileSystemLabel $Labels[$i] -Confirm:$false

}
