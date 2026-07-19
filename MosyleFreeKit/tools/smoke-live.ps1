<#
.SYNOPSIS
    Live smoke against your own Mosyle Manager Free school.
.DESCRIPTION
    Runs non-destructive checks against an explicit allowlist of devices YOU own.
    There is no built-in device list — supply -SerialNumber, or put one serial per
    line in an allowlist file (default: tools/smoke-allowlist.txt, gitignored).

    Per device: clears pending, then
      Lock -Verify (required pass)
      SendPush / UpdateInfo (soft-OK + optional verify)
      Tag add then remove (probe tag FreeKit-smoke)
    Optional: Shutdown / Restart report, Set-MosyleFreeDeviceAccount when -AccountId set.
    Destructive ops (wipe / lost mode) are never used here.
.EXAMPLE
    ./tools/smoke-live.ps1 -IdSchool yourschool -SerialNumber ABCD1234EFGH
.EXAMPLE
    ./tools/smoke-live.ps1 -IdSchool yourschool -IncludeShutdown -IncludeRestartReport
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $IdSchool,
    [string] $CookieFile = (Join-Path $PSScriptRoot '..' 'secrets' 'cookie.txt'),
    [string[]] $SerialNumber,
    [string] $AllowlistFile = (Join-Path $PSScriptRoot 'smoke-allowlist.txt'),
    [string] $ProbeTag = 'FreeKit-smoke',
    [string] $AccountId,
    [switch] $IncludeShutdown,
    [switch] $IncludeRestartReport,
    [switch] $SkipClear,
    [switch] $SkipTag,
    [switch] $SkipPushInfo
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$module = Join-Path $PSScriptRoot '..' 'src' 'MosyleFreeKit' 'MosyleFreeKit.psd1'
Import-Module $module -Force

if (-not (Test-Path -LiteralPath $CookieFile)) {
    throw "Cookie file missing: $CookieFile (write PHPSESSID=... or credentials=... )"
}

# Allowlist is explicit and local: never ship device identifiers in the repo.
if (-not $SerialNumber) {
    if (Test-Path -LiteralPath $AllowlistFile) {
        $SerialNumber = @(
            Get-Content -LiteralPath $AllowlistFile |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_ -and -not $_.StartsWith('#') }
        )
    }
}
if (-not $SerialNumber) {
    throw "No devices to smoke. Pass -SerialNumber, or list one serial per line in $AllowlistFile. These must be devices you administer."
}

Write-Host "== Connect ($IdSchool) ==" -ForegroundColor Cyan
Connect-MosyleFree -IdSchool $IdSchool -CookieFile $CookieFile -Os ios
Get-MosyleFreeSession | Format-List IdSchool, Os, BaseUri, ConnectedAt

Write-Host "== Resolve $($SerialNumber.Count) serials ==" -ForegroundColor Cyan
$devices = @(Get-MosyleFreeDevice -SerialNumber $SerialNumber)
$devices | Select-Object serial_number, UDID, device_name, date_info | Format-Table -AutoSize
$missing = @($SerialNumber | Where-Object { $_ -notin @($devices.serial_number) })
if ($missing.Count) {
    Write-Warning ("Unresolved serials: " + ($missing -join ', '))
}
if ($devices.Count -eq 0) { throw 'No devices resolved for allowlist.' }

$results = [System.Collections.Generic.List[object]]::new()

foreach ($target in $devices) {
    Write-Host "-- $($target.serial_number) --" -ForegroundColor DarkCyan

    if (-not $SkipClear) {
        $null = Invoke-MosyleFreeDeviceCommand -Command ClearPendingCommands `
            -Device $target.UDID -SerialNumber $target.serial_number `
            -Confirm:$false -DelayMs 150 -Verify
    }

    $lock = Invoke-MosyleFreeDeviceCommand -Command Lock `
        -Device $target.UDID -SerialNumber $target.serial_number `
        -LockMessage 'MosyleFreeKit allowlist smoke' `
        -Confirm:$false -DelayMs 200 -Verify

    $row = [ordered]@{
        Serial         = $target.serial_number
        UDID           = $target.UDID
        LockOk         = [bool]$lock.Ok
        LockQueued     = $lock.Queued
        PushOk         = $null
        UpdateInfoOk   = $null
        TagAddOk       = $null
        TagRemoveOk    = $null
        AccountOk      = $null
        ShutdownOk     = $null
        ShutdownQueued = $null
        RestartOk      = $null
        RestartQueued  = $null
    }

    if (-not $SkipPushInfo) {
        $push = Invoke-MosyleFreeDeviceCommand -Command SendPush `
            -Device $target.UDID -SerialNumber $target.serial_number `
            -Confirm:$false -DelayMs 200
        $row.PushOk = [bool]$push.Ok

        $info = Invoke-MosyleFreeDeviceCommand -Command UpdateInfo `
            -Device $target.UDID -SerialNumber $target.serial_number `
            -Confirm:$false -DelayMs 200
        $row.UpdateInfoOk = [bool]$info.Ok
    }

    if (-not $SkipTag) {
        $add = Set-MosyleFreeDeviceTag -Device $target.UDID -Tag $ProbeTag `
            -SerialNumber $target.serial_number -Confirm:$false -DelayMs 200
        $row.TagAddOk = [bool]$add.Ok

        $rm = Remove-MosyleFreeDeviceTag -Device $target.UDID -Tag $ProbeTag `
            -SerialNumber $target.serial_number -Confirm:$false -DelayMs 200
        $row.TagRemoveOk = [bool]$rm.Ok
    }

    if ($AccountId) {
        $acct = Set-MosyleFreeDeviceAccount -Device $target.UDID -AccountId $AccountId `
            -SerialNumber $target.serial_number -Confirm:$false -DelayMs 200
        $row.AccountOk = [bool]$acct.Ok
    }

    if ($IncludeShutdown) {
        $shut = Invoke-MosyleFreeDeviceCommand -Command Shutdown `
            -Device $target.UDID -SerialNumber $target.serial_number `
            -Confirm:$false -DelayMs 200 -Verify
        $row.ShutdownOk = [bool]$shut.Ok
        $row.ShutdownQueued = $shut.Queued
    }

    if ($IncludeRestartReport) {
        $restart = Invoke-MosyleFreeDeviceCommand -Command Restart `
            -Device $target.UDID -SerialNumber $target.serial_number `
            -Confirm:$false -DelayMs 200 -Verify
        $row.RestartOk = [bool]$restart.Ok
        $row.RestartQueued = $restart.Queued
    }

    $results.Add([pscustomobject]$row)
}

Write-Host '== Allowlist summary ==' -ForegroundColor Cyan
$results | Format-Table -AutoSize

$lockQueued = @($results | Where-Object { $_.LockQueued -eq $true }).Count
$lockFail = @($results | Where-Object { -not $_.LockOk -or $_.LockQueued -ne $true })

Write-Host "Lock queued: $lockQueued / $($results.Count)" -ForegroundColor $(if ($lockFail.Count) { 'Yellow' } else { 'Green' })
if ($lockFail.Count) {
    Write-Warning 'Devices that did not verify Lock queue:'
    $lockFail | Format-Table Serial, LockOk, LockQueued -AutoSize
    exit 2
}

if (-not $SkipPushInfo) {
    $pushFail = @($results | Where-Object { -not $_.PushOk -or -not $_.UpdateInfoOk })
    if ($pushFail.Count) {
        Write-Warning 'SendPush / UpdateInfo soft-OK failures:'
        $pushFail | Format-Table Serial, PushOk, UpdateInfoOk -AutoSize
    }
}

if (-not $SkipTag) {
    $tagFail = @($results | Where-Object { -not $_.TagAddOk -or -not $_.TagRemoveOk })
    if ($tagFail.Count) {
        Write-Warning 'Tag add/remove soft-OK failures:'
        $tagFail | Format-Table Serial, TagAddOk, TagRemoveOk -AutoSize
    }
}

Write-Host 'Smoke OK: Lock queued on full allowlist; push/info/tag exercised.' -ForegroundColor Green
