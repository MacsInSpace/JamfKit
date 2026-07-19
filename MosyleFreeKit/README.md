# MosyleFreeKit

A modern, cross-platform PowerShell 7 module for **Mosyle Manager Free** schools.

Part of **[MDMKit](../)** — PowerShell 7 modules for Apple MDM platforms. Siblings:
[JamfProKit](../JamfProKit/), [JamfSchoolKit](../JamfSchoolKit/), [MosyleKit](../MosyleKit/).

Free tenants have **no** `managerapi.mosyle.com` access token. This module uses the same
web UI session as the browser (`myschool.mosyle.com` → `Controller/mapping.php` and
`devices_list_ajax.php`).

> **Not MosyleKit.** Paid JWT API coverage lives in [MosyleKit](../MosyleKit/) — do not mix
> the two session types.

## Scope and caution

Read this before using it in anger:

- **This is not a supported API.** It drives private, unversioned web-UI endpoints. Mosyle
  can change them without notice, and there is no deprecation window.
- **Some operations the UI badges "Premium" are accepted by the server on Free.** Automating
  them may run against Mosyle's terms — check your agreement before relying on it. If the
  paid API add-on is within reach, [MosyleKit](../MosyleKit/) is the stable, supported path.
- **Only point it at a tenant you administer.**
- **Destructive commands are real.** `Wipe` erases devices, and the Free bus returns a soft
  `OK` that is not proof of anything. See below.

## Soft `OK` is not enough

Free `mapping.php` often returns `{ "status": "OK" }` even when nothing queued — and it has
been observed doing so for empty or unknown device IDs. Always use `-Verify` (settle +
retries) or `Get-MosyleFreeDeviceCommand` before trusting a send. Treat `Wipe` with the
suspicion it deserves.

## Docs

| Doc | Topic |
|-----|--------|
| [docs/AUTH.md](docs/AUTH.md) | **Start here** — connecting, cookie formats, troubleshooting |
| [docs/ENDPOINTS.md](docs/ENDPOINTS.md) | Endpoint reference: every operation, its body fields, the cmdlet that drives it, and the traps |
| [docs/LIMITS.md](docs/LIMITS.md) | Soft-OK traps, supervised vs unsupervised, Shared Device Groups, platforms |
| [docs/AGENT-HANDOFF.md](docs/AGENT-HANDOFF.md) | Discovery notes and open questions |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |

## Quick start

```powershell
Import-Module ./src/MosyleFreeKit/MosyleFreeKit.psd1

# Guided first run: prints the click-path, takes a paste, detects your school.
# -SaveCookie means later runs just work. See docs/AUTH.md.
Connect-MosyleFree -SaveCookie

Get-MosyleFreeDevice -Os ios | Select-Object -First 5 deviceudid, serial_number, device_name

$targets = Get-MosyleFreeDevice -SerialNumber ABCD1234EFGH, WXYZ5678IJKL
$targets | Invoke-MosyleFreeDeviceCommand -Command Lock -LockMessage 'IT probe' -Verify
Get-MosyleFreeDeviceCommand -Device $targets[0].deviceudid -SerialNumber $targets[0].serial_number

Invoke-MosyleFreeDeviceCommand -Command SendPush -Device $udid -WhatIf
Invoke-MosyleFreeDeviceCommand -Command UpdateInfo -Device $udid -WhatIf
Set-MosyleFreeDeviceTag -Device $udid -Tag 'Loaner' -WhatIf
Remove-MosyleFreeDeviceTag -Device $udid -Tag 'Loaner' -WhatIf
Set-MosyleFreeDeviceAccount -Device $udid -AccountId '12345' -WhatIf
Get-MosyleFreeSharedDeviceGroup
Add-MosyleFreeDeviceSharedGroup -Device $udid -Name 'Student Devices' -WhatIf
Remove-MosyleFreeDeviceSharedGroup -Device $udid -WhatIf
New-MosyleFreeSharedDeviceGroup -Name 'FreeKit Temp' -WhatIf
```

## Cmdlets (v0.5.0)

`-Os ios|mac|tvos|visionos` on Connect and device cmdlets. **iOS** is live-validated; **mac/tvOS/visionOS** use the same Free bus (list/session OK) — command delivery is best-effort until you have a test device (see [docs/LIMITS.md](docs/LIMITS.md)).

| Area | Cmdlets |
|---|---|
| Session | `Connect-MosyleFree`, `Disconnect-MosyleFree`, `Get-MosyleFreeSession` |
| Generic UI bus | `Invoke-MosyleFreeUi` |
| Devices | `Get-MosyleFreeDevice`, `Get-MosyleFreeDeviceCommand`, `Invoke-MosyleFreeDeviceCommand` |
| Lost Mode | `Invoke-MosyleFreeLostMode` |
| Inventory | `Set-MosyleFreeDeviceName`, `Set-MosyleFreeDeviceTag`, `Remove-MosyleFreeDeviceTag`, `Set-MosyleFreeDeviceAccount` |
| Shared Device Groups | `Get/New/Remove-MosyleFreeSharedDeviceGroup`, `Add/Remove-MosyleFreeDeviceSharedGroup`, `Set-MosyleFreeDeviceLimbo` |

### `Invoke-MosyleFreeDeviceCommand`

Restart, Shutdown, Lock, Wipe, Unassign (limbo), Clear*, Activation Lock,
**SendPush** (`bulk_send_push`), **UpdateInfo** (`update_info`).

`-Verify` sets `Queued` from the device Commands tab (soft OK alone is not enough).
It waits `-VerifySettleMs` (default 500) and retries `-VerifyAttempts` (default 3).

### Inventory hygiene

- `Set-MosyleFreeDeviceTag` / `Remove-MosyleFreeDeviceTag` — `devices_bulk_add_tag` / `devices_bulk_remove_tag`
- `Set-MosyleFreeDeviceAccount` — `DeviceInfoController` / `change_device_account` (`newAccount`)
- `Get-MosyleFreeSharedDeviceGroup` — list name ↔ `GroupId` (`carts_list.php` + `carts_info`)
- `New-MosyleFreeSharedDeviceGroup` / `Remove-MosyleFreeSharedDeviceGroup` — create/delete groups (`save_cart` / `delete_cart`)
- `Add-MosyleFreeDeviceSharedGroup` — device → group (`change_to_sharedenroll`, `idcart=[N]` or `-Name`)
- `Remove-MosyleFreeDeviceSharedGroup` — device ← group (`change_to_limbo`)
- End-user 1:1 assign UI was not available on Free for capture; account move is what we ship

## Reaching something that isn't wired yet

Every operation goes through one bus, so anything mapped in
[docs/ENDPOINTS.md](docs/ENDPOINTS.md) is reachable even without a typed cmdlet:

```powershell
Invoke-MosyleFreeUi -Mapping BulkOperationsController -Operation some_operation -Body @{ deviceudid = $udid }
```

To find the body a UI feature sends, [`tools/capture-ui-network.js`](tools/capture-ui-network.js)
records the Mosyle UI's own fetch/XHR traffic from the DevTools Console — paste it, click the
feature once, then `mosyleDumpCapture()`. Captures contain live session traffic and device
identifiers, so keep them out of version control.

## Development

```powershell
./build.ps1                                              # analyze + test + package
./tools/smoke-live.ps1 -IdSchool yourschool -SerialNumber ABCD1234EFGH
```

One function per file under `src/MosyleFreeKit/{Public,Private}`; the release build flattens
to a single `.psm1`. Tests are Pester 5 with all HTTP mocked at a single seam
(`Invoke-MosyleFreeHttp`) — the suite runs with no network and no Mosyle tenant.

`smoke-live.ps1` *does* hit the network, and has no built-in device list: pass
`-SerialNumber`, or list one serial per line in `tools/smoke-allowlist.txt` (gitignored).
Only ever list devices you administer.

## License

[MIT](../LICENSE) (same family as MDMKit modules)
