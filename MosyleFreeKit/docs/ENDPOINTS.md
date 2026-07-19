# Free-tier UI endpoint reference

What the Mosyle Manager Free web UI accepts, and which cmdlet drives it.

Captured from a Free tenant's own browser traffic (2026-07-18) during the feasibility
spike that preceded this module. Tenant identifiers are deliberately not recorded here.

> **These are private, unversioned endpoints.** Mosyle can change any of them without
> notice. Nothing below is a documented API. See the scope note in the
> [README](../README.md#scope-and-caution).

## Auth

| Item | Value |
|------|-------|
| Base | `https://myschool.mosyle.com` |
| Mechanism | Session cookies — `credentials` (JWT, `.mosyle.com`) and/or `PHPSESSID` |
| Session exchange | `GET /` with `credentials` usually issues `Set-Cookie: PHPSESSID`, needed for most `mapping.php` posts (401 without it) |
| Command bus | `POST Controller/mapping.php` with `mapping` + `operation` |
| List bus | `POST screens/scules/mdm/bulkoperations/devices_list_ajax.php` |
| School context | Every call carries `usertab_current_idschool` and `usertab_current_os` |

Connecting is covered in [AUTH.md](AUTH.md).

## Status legend

- **works** — the server accepts the call on Free (it may still validate devices/password)
- **untested** — not captured; do not wire up without capturing first

Several operations below carry a **Premium badge in the UI but are accepted by the server
on Free**. That gap is why this module exists, and also why it may sit outside Mosyle's
terms — read the scope note before leaning on it.

## Operations

All `Controller/mapping.php` unless noted. `{udid}` = `deviceudid`, `{serial}` =
`serial_number`; both are usually sent together.

| Operation | Free | mapping / operation | Extra body fields | Cmdlet |
|---|---|---|---|---|
| List devices | works | *(`devices_list_ajax.php`)* | `page`, `term`, `term_by`, `source_page` | `Get-MosyleFreeDevice` |
| Restart | works | `BulkOperationsController` / `bulk_restart` | `devices`, `password` | `Invoke-MosyleFreeDeviceCommand -Command Restart` |
| Shutdown | works | `BulkOperationsController` / `bulk_shutdown` | `devices`, `password` | `… -Command Shutdown` |
| Lock | works | `BulkOperationsController` / `lock_device` | `pin_code`, `LockMessage`, `LockPhone`, `password` | `… -Command Lock` |
| Clear commands | works | `CommandController` / `device_clear_commands` | `command_status` (**not** `status`) | `… -Command ClearCommands` |
| Send push | works | `BulkOperationsController` / `bulk_send_push` | — | `… -Command SendPush` |
| Update info | works | `BulkOperationsController` / `update_info` | — | `… -Command UpdateInfo` |
| Wipe | works | `BulkOperationsController` / `wipe_device` | `pin_code`, `password` | `… -Command Wipe` |
| Activation Lock on | works | `BulkOperationsController` / `bulk_enable_activation_lock` | `lost_message` (required) | `… -Command EnableActivationLock` |
| Activation Lock off | works | `BulkOperationsController` / `disable_activationlock` | — | `… -Command DisableActivationLock` |
| Unassign / limbo | works | `DeviceInfoController` / `change_to_limbo` | `action` = `remove_apps` 0/1 | `… -Command Unassign`, `Set-MosyleFreeDeviceLimbo` |
| Rename | works | `BulkOperationsController` / `bullk_change_devicesname` | `devices`, `newname`, `action` | `Set-MosyleFreeDeviceName` |
| Add tag | works | `BulkOperationsController` / `devices_bulk_add_tag` | `devices`, `tag_name` | `Set-MosyleFreeDeviceTag` |
| Remove tag | works | `BulkOperationsController` / `devices_bulk_remove_tag` | `devices`, `tag_name`, `turn` | `Remove-MosyleFreeDeviceTag` |
| Assign account | works | `DeviceInfoController` / `change_device_account` | `newAccount` (idaccount) | `Set-MosyleFreeDeviceAccount` |
| Add to Shared Device Group | works | `DeviceInfoController` / `change_to_sharedenroll` | `idcart` | `Add-MosyleFreeDeviceSharedGroup` |
| Lost Mode | works | `BulkOperationsController` / `ios_enable_lostmode` | `message`, `phone`, `footnote` | `Invoke-MosyleFreeLostMode` |
| Update device attributes | untested | — | — | *not wired* |
| Device Group membership | untested | — | — | *not wired* |

Shared Device Group inventory (`HierarchyController` / `carts_info`, `save_cart`,
`delete_cart`, plus `screens/scules/hierarchy/carts_list.php`) was mapped later, during
module development — see `Get/New/Remove-MosyleFreeSharedDeviceGroup`.

Anything not wired is still reachable through the generic bus:

```powershell
Invoke-MosyleFreeUi -Mapping BulkOperationsController -Operation some_operation -Body @{ deviceudid = $udid }
```

## Traps worth knowing

These cost real debugging time:

- **Soft `OK` is not proof.** `mapping.php` returns `{"status":"OK"}` for operations that
  never queued — including for empty or unknown device IDs. `Restart` is the worst
  offender. Always `-Verify`, or check `Get-MosyleFreeDeviceCommand`.
- **`bullk_change_devicesname`** — the doubled `l` is Mosyle's typo. It is load-bearing.
- **`command_status`, not `status`** on `device_clear_commands`.
- **`idcart` must be a JSON array** (`[2]`). A bare `2` soft-OKs without assigning anything.
- **Lost Mode ops are iOS-named** and best-effort elsewhere.
- **Destructive ops usually want the admin password** in `password` — the UI raises
  `MosyleDialog.newConfirmDialogSecurity` for these. Supply `-AdminCredential`.
- **Lock and Activation Lock validate the UDID** server-side; an invalid one 500s rather
  than failing cleanly.

## Capturing new operations

[`tools/capture-ui-network.js`](../tools/capture-ui-network.js) records the UI's own
`fetch`/XHR traffic so you can read the exact body a feature sends.

1. Sign in to a Free tenant **you administer** and open Management → Devices Overview.
2. Paste the script into the DevTools Console.
3. Run `mosyleCaptureHint()` for a suggested click sequence.
4. Perform the action **once**, on a device you are willing to affect.
5. `mosyleDumpCapture()` downloads the captured requests as JSON.

Read the `requestBody` of the `mapping.php` call — that is the operation and its fields.

> The capture file contains your session's real traffic, including device identifiers.
> Treat it as sensitive and keep it out of the repo (`artifacts/` is gitignored).
