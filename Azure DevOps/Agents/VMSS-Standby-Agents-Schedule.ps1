<#
    .SYNOPSIS
                    Set "number of agents to keep standby" on Self-Hosed Azure DevOps Agent Pool
    .DESCRIPTION
                    The Script will loop the Scale Set Agent Pools, and based on the current time, it will set the appropriate "number of agents to keep standby" based on a defined schedule.
    .AUTHOR
                    Asif Mithawala

    .VERSION HISTORY
    Version 1 - 2021-03-04
        First version of script created. The Script will loop the Scale Set Agent Pools, and based on the current time, it will set the appropriate "number of agents to keep standby" based on a defined schedule.
        0 is = sunday and saturday is = 6 in the schedule
#>
param(
    [array]$AgentPools = @(
        @{name = "Ubuntu"; id = 1; schedule = '{"TzId":"W. Europe Standard Time","0":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"1":{"S":"6","Sidle":"10","E":"21","Eidle":"2"},"2":{"S":"6","Sidle":"10","E":"21","Eidle":"2"},"3":{"S":"6","Sidle":"10","E":"21","Eidle":"2"},"4":{"S":"6","Sidle":"10","E":"21","Eidle":"2"},"5":{"S":"6","Sidle":"10","E":"21","Eidle":"2"},"6":{"S":"6","Sidle":"2","E":"21","Eidle":"2"}}' },
        @{name = "Windows"; id = 2; schedule = '{"TzId":"W. Europe Standard Time","0":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"1":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"2":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"3":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"4":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"5":{"S":"6","Sidle":"2","E":"21","Eidle":"2"},"6":{"S":"6","Sidle":"2","E":"21","Eidle":"2"}}' }
    )
)

# Create a Linebreak Variable for Nice Write-Output
$linebreak = "-" * 150

# Fetch secret from KeyVault
$PATToken = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-AzKeyVaultSecret -VaultName my-vault -Name 'DevOpsAgent-PAT').SecretValue))

# Setup security and headers
$DevOpsAccount = "https://dev.azure.com/{org}"
$creds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($("user:$($PATToken)")))
$encodedAuthValue = "Basic $creds"
$acceptHeaderValue = "application/json;api-version=3.0-preview"
$headers = @{Authorization = $encodedAuthValue; Accept = $acceptHeaderValue }

# Get All VMSS Pools
$ElasticPoolsUrl = "$($DevOpsAccount)/_apis/distributedtask/elasticpools?api-version=6.1-preview.1"
$ElasticPools = Invoke-RestMethod -Method GET -UseBasicParsing -Headers $headers -Uri $ElasticPoolsUrl

foreach ($AgentPool in $AgentPools) {

    Write-Output "$linebreak"

    Write-Output "Checking AgentPool: $($AgentPool.name)" 

    $schedule = ConvertFrom-Json $AgentPool.Schedule 

    $poolTz = [System.TimeZoneInfo]::FindSystemTimeZoneById($schedule.TzId)
    $utcCurrentTime = [datetime]::UtcNow
    $poolTzCurrentTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcCurrentTime, $poolTz)

    $startTime = [int]::Parse($schedule.($poolTzCurrentTime.DayOfWeek.value__).S)

    $endTime = [int]::Parse($schedule.($poolTzCurrentTime.DayOfWeek.value__).E)

    $startTimeIdle = [int]::Parse($schedule.($poolTzCurrentTime.DayOfWeek.value__).Sidle)

    $endTimeIdle = [int]::Parse($schedule.($poolTzCurrentTime.DayOfWeek.value__).Eidle)

    Write-Output "Identified Start Time: $startTime and End Time: $endTime"

    Write-Output "Identified Start Time Number of idle Agents: $startTimeIdle and End Time Number of idle Agents: $endTimeIdle"

    Write-Output "Checking current config..."

    $ElasticPool = $ElasticPools.value | Where-Object { $_.poolId -eq $AgentPool.id }

    Write-Output $ElasticPool

    if (($poolTzCurrentTime.Hour -ge $startTime) -and ($poolTzCurrentTime.Hour -lt $endTime)) {

        Write-Output "Check if Start Time Number of idle Agents needs to be updated..."
        Write-Output "Expected Number of idle Agents should be: $startTimeIdle"
        Write-Output "Number of idle Agents currently configured is: $($ElasticPool.desiredIdle)"

        if ($startTimeIdle -eq $ElasticPool.desiredIdle) {
            Write-Output "No update is currently needed"
        }
        else {
            Write-Output "Will update number of idle Agents from: $($ElasticPool.desiredIdle) to new value: $startTimeIdle"

            $Body = @"
{
	"desiredIdle": $startTimeIdle
}
"@
            $URI = "$($DevOpsAccount)/_apis/distributedtask/elasticpools/$($ElasticPool.poolId)?api-version=6.1-preview.1"

            try {
                $response = Invoke-RestMethod -Uri $URI -headers $headers -Method PATCH -Body $Body -ContentType "application/json" -TimeoutSec 180 -ErrorAction:Stop
            }
            catch {
                write-Error $_.ErrorDetails
            }
            Write-Output $response
        }
    }

    if (($poolTzCurrentTime.Hour -le $startTime) -or ($poolTzCurrentTime.Hour -ge $endTime)) {

        Write-Output "Check if End Time Number of idle Agents needs to be updated..."
        Write-Output "Expected Number of idle Agents should be: $endTimeIdle"
        Write-Output "Number of idle Agents currently configured is: $($ElasticPool.desiredIdle)"

        if ($endTimeIdle -eq $ElasticPool.desiredIdle) {
            Write-Output "No update is currently needed"
        }
        else {
            Write-Output "Will update number of idle Agents from: $($ElasticPool.desiredIdle) to new value: $endTimeIdle"

            $Body = @"
{
	"desiredIdle": $endTimeIdle
}
"@
            $URI = "$($DevOpsAccount)/_apis/distributedtask/elasticpools/$($ElasticPool.poolId)?api-version=6.1-preview.1"

            try {
                $response = Invoke-RestMethod -Uri $URI -headers $headers -Method PATCH -Body $Body -ContentType "application/json" -TimeoutSec 180 -ErrorAction:Stop
            }
            catch {
                write-Error $_.ErrorDetails
            }
            Write-Output $response
        }
    }
}
