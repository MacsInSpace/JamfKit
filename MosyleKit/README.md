# MosyleKit

A modern, cross-platform PowerShell 7 module for the [Mosyle Manager](https://mosyle.com/) API.

Part of **[MDMKit](../)** — PowerShell 7 modules for Apple MDM platforms. Siblings:
[JamfProKit](../JamfProKit/), [JamfSchoolKit](../JamfSchoolKit/), [MosyleFreeKit](../MosyleFreeKit/).

> **On a Free plan?** The Manager API is a paid add-on, so this module needs an access token
> you can only get on a paid plan. Free tenants have **[MosyleFreeKit](../MosyleFreeKit/)**,
> which drives the web UI with your browser session instead — useful, but unsupported and
> unversioned. Where the paid API is an option, this module is the stable path.

- **JWT auth, handled.** `Connect-Mosyle` logs in with your access token + an admin email/password, reads the bearer token from the login response header, and renews it automatically before the 24-hour expiry.
- **The whole API from one cmdlet.** Every Mosyle operation is a `POST /v2/<endpoint>` with `accessToken` in the body — so `Invoke-MosyleApi -Endpoint <name>` reaches all of it today, with token renewal, retry/backoff, and Mosyle's in-body `status: ERROR` responses surfaced as real errors.
- **Typed cmdlets** for the common reads, with more to come as payloads are confirmed against the API docs.
- **Strict-mode clean**, PowerShell 7.4+, CI on macOS/Linux/Windows.

## Quick start

```powershell
# Access token: My School > API Integration (paid feature). Email/password: an admin with API permissions.
Connect-Mosyle -AccessToken (Get-Secret MosyleToken) -Credential (Get-Credential)

Get-MosyleUser -Column id, name, email
Get-MosyleDevice -Os ios
```

### The whole API via the generic cmdlet

```powershell
Invoke-MosyleApi -Endpoint listusers -Body @{ options = @{ specific_columns = @('id','name') } }
Invoke-MosyleApi -Endpoint listdynamicgroups
Invoke-MosyleApi -Endpoint listclasses
# Write operations prompt (ShouldProcess); -WhatIf to preview:
Invoke-MosyleApi -Endpoint wipe -Body @{ devices = @($udid) } -WhatIf
```

### Device commands and user provisioning

```powershell
# Bulk device commands via /bulkops — target by UDID and/or device group ID
Invoke-MosyleDeviceCommand -Command Restart -Group 210
Get-MosyleDevice -Os ios -Tag Retired | Invoke-MosyleDeviceCommand -Command Wipe -RevokeVppLicenses -Confirm:$false
Invoke-MosyleDeviceCommand -Command Lock -Device $udid -Pincode 123456 -LockMessage 'Return to IT'

# Device attributes (batched into one request when piped)
Set-MosyleDeviceAttribute -SerialNumber F9FXH12ABC -AssetTag IPAD-042 -Name 'Library iPad 7'

# Bulk user create/update — piped rosters go in one call
Import-Csv roster.csv | New-MosyleUser
Set-MosyleUser -Id student.1 -Email new.address@school.org
```

## Cmdlets (v0.3)

| Area | Cmdlets |
|---|---|
| Session | `Connect-Mosyle`, `Disconnect-Mosyle`, `Get-MosyleSession` |
| Whole API | `Invoke-MosyleApi` |
| Devices | `Get-MosyleDevice`, `Invoke-MosyleDeviceCommand`, `Set-MosyleDeviceAttribute`, `Invoke-MosyleLostMode`, `Set-MosyleDeviceOwner` |
| Device groups | `Get-MosyleDeviceGroup`, `Get-MosyleDeviceGroupDevice`, `Set-MosyleDeviceGroupMember` |
| Users | `Get-MosyleUser`, `New-MosyleUser`, `Set-MosyleUser`, `Remove-MosyleUser` |
| Classes | `Get-MosyleClass`, `New-MosyleClass`, `Remove-MosyleClass` |
| Custom attributes | `Get-/New-/Set-/Remove-MosyleCustomAttribute` |
| Logs | `Get-MosyleActionLog` |

`Invoke-MosyleDeviceCommand` covers Restart, Shutdown, Wipe, Lock, Unassign,
ClearCommands / ClearPendingCommands / ClearFailedCommands, and Enable/Disable
Activation Lock. Anything without a typed cmdlet (District accounts, Cisco ISE,
the logs-stream host) is reachable via `Invoke-MosyleApi`.

## Status &amp; roadmap

This is an early scaffold. The **session/auth core and the generic `Invoke-MosyleApi` are complete
and correct** — that generic cmdlet already covers every documented operation (list/create/update
devices, users, classes, dynamic & shared device groups, custom attributes, action logs, Cisco ISE,
district accounts). The typed cmdlets so far cover the operations whose exact request/response
shapes are confirmed (`listusers` from Mosyle's own PowerShell example; `listdevices` follows the
same options pattern).

Planned, pending payload confirmation from the API docs:
- Typed device operations: lock, lost mode, unassign, update attributes, bulk wipe/restart/shutdown/clear-commands/activation-lock
- Typed user CRUD (create/update/delete, assign devices) and class save/delete
- Dynamic & shared device groups, custom device attributes, action logs
- Shared request/retry core with the other JamfKit modules at build time

The operation map extracted from the Mosyle docs lives at
[`../../mosyle-api-docs/MOSYLE-API-MAP.md`](../../mosyle-api-docs/MOSYLE-API-MAP.md) (outside the
module tree). If you have a doc article's request/response body, paste it and the matching typed
cmdlet can be finalized.

## Development

```powershell
./build.ps1            # analyze + test + package
```

Same conventions as the other modules: one function per file, single mocked HTTP seam, no network in tests.

## License

[MIT](../LICENSE)
