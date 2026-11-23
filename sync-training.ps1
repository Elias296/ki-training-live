[CmdletBinding()]
param(
    [string]$Repository = 'Elias296/ki-training-live',
    [ValidateRange(60, 3600)]
    [int]$IntervalSeconds = 60,
    [ValidateRange(1, 24)]
    [int]$DurationHours = 12,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
$statusEndpoint = "repos/$Repository/contents/status.json"
$statusBranch = 'status'
$expiresAt = [DateTimeOffset]::UtcNow.AddHours($DurationHours)
$lastStep = $null
$lastAdvance = [DateTimeOffset]::UtcNow
$sha = $null

do {
    try {
        $training = Invoke-RestMethod -Uri 'http://127.0.0.1:8770/data' -TimeoutSec 10
        $latest = $training.last
        if ($null -eq $latest.step -or $latest.step -lt 0 -or $latest.total -le 0) {
            throw 'The training service has no valid progress data.'
        }

        $now = [DateTimeOffset]::UtcNow
        if ($latest.step -ne $lastStep) {
            $lastStep = $latest.step
            $lastAdvance = $now
        }

        $state = 'paused'
        if ($training.ende -eq $true) {
            $state = 'complete'
        } elseif ($training.state -like 'l?uft' -and ($now - $lastAdvance).TotalMinutes -lt 4) {
            $state = 'running'
        }

        $validation = $null
        if ($training.vals.Count -gt 0) {
            $validation = $training.vals[-1][1]
        }

        $snapshot = [ordered]@{
            updatedAt       = $now.ToString('o')
            state           = $state
            step            = [long]$latest.step
            total           = [long]$latest.total
            tokensPerSecond = $latest.rate
            etaHours        = $latest.eta
            validationLoss  = $validation
        } | ConvertTo-Json -Compress

        if (-not $sha) {
            $sha = gh api "${statusEndpoint}?ref=$statusBranch" --jq '.sha' 2>$null
            if ($LASTEXITCODE -ne 0) {
                $sha = $null
            }
        }

        $body = @{
            message = 'Update training status'
            branch  = $statusBranch
            content = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($snapshot))
        }
        if ($sha) {
            $body.sha = $sha
        }

        $sha = ($body | ConvertTo-Json -Compress) | gh api --method PUT $statusEndpoint --input - --jq '.content.sha'
        if ($LASTEXITCODE -ne 0 -or -not $sha) {
            $sha = $null
            throw 'GitHub did not accept the snapshot.'
        }
        Write-Output "${now}: $state, step $($latest.step)/$($latest.total)"

        if ($Once -or $state -eq 'complete') {
            break
        }
    } catch {
        $sha = $null
        if ($Once) {
            throw
        }
        Write-Warning $_.Exception.Message
    }
    Start-Sleep -Seconds $IntervalSeconds
} while ([DateTimeOffset]::UtcNow -lt $expiresAt)
