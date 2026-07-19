# MosyleFreeKit — Free UI limits (live notes)

Verified on the Free test tenant (`yourschool`) with supervised ASM iPad `ABCD1234EFGH` and the
stale serial allowlist. Soft `{ "status": "OK" }` alone is never proof of delivery.

## Soft OK traps

| Trap | Symptom | Mitigation |
|------|---------|------------|
| Soft OK, empty queue | Restart (esp. unsupervised / busy queue) | `-Verify` (settle + retries) or Commands tab |
| Soft OK, no inventory change | `idcart=2` instead of `[2]` for Shared Device Groups | `Add-MosyleFreeDeviceSharedGroup` formats `[N]` |
| Soft OK, limbo/account lag | Assignment fields slow to refresh | Re-`Get-MosyleFreeDevice` after a few seconds |
| Clear with wrong field | `status=` → 500 “What is the status?” | Use `command_status=pending` (kit default) |

## Supervised vs unsupervised (iOS)

| Op | Unsupervised (Safari enroll) | Supervised (ASM / ADE) |
|----|------------------------------|-------------------------|
| Lock | Works (no custom lock message) | Works; message/phone more reliable |
| Lock message / phone | Often ignored | Shows on lock screen / Lost Mode |
| Rename (`Set-MosyleFreeDeviceName`) | Queues then drops; Settings rename still works | Queues and applies |
| Restart | Soft OK common; queue unreliable | Queues as **Restart OS** (use `-Verify`) |
| Shutdown | Queues on allowlist | Queues on live device |
| Lost Mode + PlaySound | Needs supervision | Enable / Disable / PlaySound / location work |
| Wipe / Erase | Possible but limited | Verified erase + ADE re-enroll path |
| Shared Device Group assign | Works when `idcart=[N]` | Same |

## Platforms (iOS / macOS / tvOS / visionOS)

All FreeKit cmdlets take `-Os ios|mac|tvos|visionos` (or inherit from `Connect-MosyleFree -Os`).
The same UI bus is used; Mosyle switches the school device list via `usertab_current_os`.

| Platform | List / session | Commands | Notes |
|----------|----------------|----------|--------|
| **ios** | Validated live (the Free test tenant) | Validated on supervised ASM iPad | Primary supported path |
| **mac** | List/session OK (empty school → empty array) | Same op names; **no test Mac** | Lock may prompt for `-PinCode` in UI; Lost Mode ops are iOS-named |
| **tvos** | List/session OK | Same op names; **no test Apple TV** | Best-effort |
| **visionos** | List/session OK | Untested | Same bus |

**Best-effort rule:** soft `status:OK` on mac/tvOS without a Commands-tab row means the platform likely ignored the op — use `-Verify` / `Get-MosyleFreeDeviceCommand` once you have a device.

Mac-only UI extras in Free JS (not separate FreeKit cmdlets): ARD helper flows, `restart_mac` dialog wrapping the same `bulk_restart` op. Use `Restart-MosyleFreeDevice` / `Stop-MosyleFreeDevice` with `-Os mac`.

Empty OS lists used to throw under `Set-StrictMode` (empty `devices:[]` unrolled to `$null`). Fixed in `Get-MosyleFreeDevice` — `Get-MosyleFreeDevice -Os mac` returns nothing cleanly when the school has no Macs.

## Shared Device Groups

UI name (was “Shared Device Carts”). the Free test tenant examples:

| GroupId | Name |
|---------|------|
| 1 | Staff Devices |
| 2 | Student Devices |

- List: `Get-MosyleFreeSharedDeviceGroup`
- Device in/out: `Add-MosyleFreeDeviceSharedGroup` / `Remove-MosyleFreeDeviceSharedGroup`
- Create/delete group: `New-MosyleFreeSharedDeviceGroup` / `Remove-MosyleFreeSharedDeviceGroup`
- Create requires `-LocationId` (JSON `idunits`, default `1`)

“Student Devices” here is a **Shared Device Group name**, not 1:1 student assignment (`iduser`).

## Auth reminder

See [AUTH.md](AUTH.md). `credentials` JWT alone is often not enough for `mapping.php` —
Connect exchanges via GET `/` for `PHPSESSID`.

## Not covered / higher risk

- 1:1 student assign (`link_user_device`) — Free UI not captured
- Activation Lock enable/disable — in kit, not live-burned in
- Second Free school — same paths, not exercised
- macOS / tvOS / visionOS command *delivery* — list/session exercised; no test devices for queue verify
- Paid `managerapi.mosyle.com` — use **MosyleKit**
