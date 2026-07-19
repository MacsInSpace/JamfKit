# Agent handoff — MosyleFreeKit (2026-07-19)

Read this first before continuing Free-tier work. Product docs: [AUTH.md](AUTH.md), [LIMITS.md](LIMITS.md), [README](../README.md), [CHANGELOG](../CHANGELOG.md).

## Current version

**v0.5.0-alpha** — build green (`./build.ps1`, 49 Pester tests).  
Module: `MosyleFreeKit/` (not MosyleKit). Endpoint discovery was done against a Free tenant;
tenant-specific identifiers are deliberately not committed.

## What this kit is

PowerShell 7 automation for **Mosyle Manager Free** via the browser UI session (`*.mosyle.com` → `Controller/mapping.php`, list AJAX, device Commands HTML). No `managerapi.mosyle.com`. Do not mix with paid **MosyleKit** sessions.

Related (do not conflate):

| Path | Role |
|------|------|
| `MosyleFreeKit/` | This module |
| `MosyleKit/` | Paid `managerapi` JWT API — separate session type |

Earlier discovery scaffolding (endpoint matrix, PHP bridge spike, browser extension) is
kept out of this repo: it is tied to a specific tenant's captured pages.

## Auth (required for live work)

1. `Connect-MosyleFree -SaveCookie` — guided paste, detects the school, persists to
   `~/.mosylefreekit/cookie.txt` (0600)
2. Or supply your own: `-Cookie`, `-CookieFile`, or `$env:MOSYLEFREEKIT_COOKIE`
3. Connect hits GET `/` so `PHPSESSID` lands in the jar; JWT alone often fails `mapping.php`

See [AUTH.md](AUTH.md). Cookie expires — refresh from DevTools if live calls 302 to login.

## Live devices (iOS)

| Serial | Notes |
|--------|--------|
| `ABCD1234EFGH` | **Main test** — ASM supervised iPad; UDID `d23b4ad59550985c51a922bb8a40892122d2d84e` |
| `WXYZ5678IJKL` | Early unsupervised Safari enroll — Lock OK; rename / lock message unreliable |

Prefer supervised ASM for fair command tests. Destructive ops (Wipe / Shutdown) only with explicit user OK on their test device.

### Verified on supervised ASM (`ABCD1234EFGH`)

Rename, Lock+message, Lost Mode on/off/PlaySound/location, Restart (`Restart OS` + `-Verify`), Wipe, Shutdown, SendPush/UpdateInfo (soft OK), tags, Shared Device Group assign.

## Platforms — stop here if picking up mac/tvOS

| OS | List / session (the Free test tenant) | Command delivery |
|----|--------------------------|------------------|
| `ios` | Live validated | Live validated (supervised iPad) |
| `mac` | Empty list OK | **No test Mac** — best-effort same op names |
| `tvos` | Empty list OK | **No test Apple TV** — best-effort |
| `visionos` | Empty list OK | Untested |

**Do not invent live command success for mac/tvOS without devices.** Use `-Verify` / `Get-MosyleFreeDeviceCommand` when a device appears.

Same bus: `usertab_current_os` + `-Os ios|mac|tvos|visionos`. Lost Mode posts iOS-named ops (`ios_enable_lostmode`, …). Mac UI has ARD / `restart_mac` dialog wrapping `bulk_restart` — not separate FreeKit cmdlets.

**Bug fixed in 0.4.3:** empty `devices:[]` under StrictMode used to throw (array unroll → `$null` → `.Count` / nested `@()`). `Get-MosyleFreeDevice` returns a List via unary comma; callers must not re-wrap with `@(& $invokeList)`. Unit test covers empty mac list.

## Soft OK traps (always)

Soft `{ "status": "OK" }` ≠ queued. Use `-Verify` (`-VerifySettleMs` 500, `-VerifyAttempts` 3) or Commands tab.

| Trap | Fix |
|------|-----|
| Restart missing from queue | `-Verify` settle/retries; label **Restart OS** |
| Shared group assign no-op | `idcart` must be JSON array `[2]`, not bare `2` |
| Clear pending 500 | Field is `command_status=pending`, not `status` |

Full table: [LIMITS.md](LIMITS.md).

## Shared Device Groups (UI name)

Not “carts” in the UI; bus still uses `idcart` / `carts_*` / `save_cart`.

the Free test tenant: **1 = Staff Devices**, **2 = Student Devices** (group name ≠ 1:1 `iduser`).

| Action | Mechanism |
|--------|-----------|
| List | `carts_list.php` + `HierarchyController` / `carts_info` with `idcart=[1,2]` |
| Add device | `change_to_sharedenroll`, `idcart=[N]` |
| Remove device | `change_to_limbo` |
| Create / delete group | `save_cart` / `delete_cart` (+ NotesToken from form) |

Cmdlets: `Get/New/Remove-MosyleFreeSharedDeviceGroup`, `Add/Remove-MosyleFreeDeviceSharedGroup`, `Set-MosyleFreeDeviceLimbo`.

## Constraints

- Do not alter MosyleKit; do not raw-fetch `article.php` for secrets
- Write/destructive Free ops: confirm with user first
- Prefer `-WhatIf` then live on allowlisted / known test serials

## Suggested next work (when user asks)

1. If a Mac or Apple TV enrolls: Connect `-Os mac|tvos`, list, then Lock/Restart/SendPush with `-Verify`; update LIMITS with real results
2. 1:1 student assign (`link_user_device`) — still not captured on Free UI
3. Activation Lock — in kit, not live-burned
4. Cookie refresh / Connect resilience if auth flakes overnight

## Quick smoke

```powershell
cd MosyleFreeKit
./build.ps1
Import-Module ./dist/MosyleFreeKit/MosyleFreeKit.psd1 -Force
Connect-MosyleFree -IdSchool yourschool -CookieFile ./secrets/cookie.txt
@(Get-MosyleFreeDevice -Os ios -Page 1).Count   # expect many
@(Get-MosyleFreeDevice -Os mac -Page 1).Count    # expect 0 at the Free test tenant
Get-MosyleFreeDevice -SerialNumber ABCD1234EFGH | Get-MosyleFreeDeviceCommand
```

Artifacts for UI discovery: `MosyleFreeKit/artifacts/js_1140_classes_mdm.bulkoperations.js`, `manager.sharedgroup.js`.
