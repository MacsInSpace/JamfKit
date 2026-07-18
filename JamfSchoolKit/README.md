# JamfSchoolKit

A modern, cross-platform PowerShell 7 module for the [Jamf School](https://www.jamf.com/products/jamf-school/) API — and, as far as we can tell, **the first Jamf School PowerShell module, full stop**.

- **Zero-ceremony auth.** Jamf School uses HTTP Basic auth (Network ID + API key, never expires). Connect once; the credential rides every call. SecretManagement-friendly: `-ApiKey (Get-Secret JamfSchool)`.
- **The protocol-version footgun, fixed.** The API silently falls back to ancient v1 response shapes when `X-Server-Protocol-Version` is missing. This module always sends it (default 3, per-session and per-call overrides).
- **Typed cmdlets for the admin surface**: devices (with server-side filters and MDM-style commands), users, classes, and device/user groups — envelope unwrapping, string-boolean quirks and the HTTP-200-but-failed responses (`UnlockFailed`) all handled.
- **Hardened engine**: retry with backoff honoring `Retry-After`, normalized errors surfacing the API's `message`/`reason`, strict-mode clean, PowerShell 7.4+, CI on macOS/Linux/Windows.

## Quick start

```powershell
# Network ID: Devices > Enroll Device(s). API key: Settings > API.
Connect-JamfSchool -Url https://yourschool.jamfcloud.com -NetworkId 1234567890 -ApiKey (Get-Secret JamfSchool)

Get-JamfSchoolDevice -Groups 12 -Supervised $true
Get-JamfSchoolDevice -SerialNumber F9FXH12ABC
```

### Devices

```powershell
# Commands: Restart, Wipe, Refresh, Restore, Unenroll, ClearActivationLock — all -WhatIf-able
Invoke-JamfSchoolDeviceCommand -Udid $udid -Command Restart
Get-JamfSchoolDevice -Groups 12 | Invoke-JamfSchoolDeviceCommand -Command Refresh -Confirm:$false

Set-JamfSchoolDeviceOwner -Udid $udid -UserId 1234    # or -Clear
Set-JamfSchoolDeviceGroupMember -GroupId 12 -Add $udid1, $udid2 -Remove $udid3
```

### Users and classes

```powershell
Import-Csv new-students.csv | New-JamfSchoolUser                  # CSV headers bind by name
Set-JamfSchoolUser -Id 555 -Password (Get-Secret ResetPw)         # dedicated endpoint, handled
Set-JamfSchoolUser -Id 555 -MemberOf 'Students', 'Year 8'         # names auto-created, replaces membership

New-JamfSchoolClass -Name 'Year 8 Science' -Teachers 113971 -Students 123, 456
Set-JamfSchoolClass -Uuid $uuid -RemoveStudents all
Get-JamfSchoolClass -Uuid $uuid -Devices
```

### Everything else

```powershell
Invoke-JamfSchoolApi -Path 'ibeacons'
Invoke-JamfSchoolApi -Method POST -Path 'ibeacons' -Body @{ name = 'Library'; uuid = $u; major = 1; minor = 2 }
```

## Cmdlets (v0.1)

| Area | Cmdlets |
|---|---|
| Session | `Connect-JamfSchool`, `Disconnect-JamfSchool`, `Get-JamfSchoolSession` |
| Escape hatch | `Invoke-JamfSchoolApi` |
| Devices | `Get-JamfSchoolDevice`, `Invoke-JamfSchoolDeviceCommand`, `Set-JamfSchoolDeviceOwner`, `Remove-JamfSchoolDevice` |
| Device groups | `Get-JamfSchoolDeviceGroup`, `Set-JamfSchoolDeviceGroupMember` |
| Users | `Get-JamfSchoolUser`, `New-JamfSchoolUser`, `Set-JamfSchoolUser`, `Remove-JamfSchoolUser`, `Get-JamfSchoolUserGroup` |
| Classes | `Get-JamfSchoolClass`, `New-JamfSchoolClass`, `Set-JamfSchoolClass`, `Remove-JamfSchoolClass` |

## Roadmap

- Device/user group create/update/delete, locations, iBeacons, profiles (read), apps
- DEP placeholders and `POST /users/bulk` CSV import
- Shared core with [JamfProKit](../JamfProKit/) at build time
- Teacher sub-API (its own token auth) — if there's demand

## Development

```powershell
./build.ps1            # analyze + test + package
```

Same conventions as JamfProKit: one function per file, single mocked HTTP seam, no network in tests. See the [JamfProKit README](../JamfProKit/README.md) for the acknowledgements that apply repo-wide.

## License

[MIT](../LICENSE)
