# MosyleFreeKit changelog

## 0.5.0-alpha

First release inside the [MDMKit](https://github.com/MacsInSpace/MDMKit) repo.

### Connecting is now a one-liner
- `Connect-MosyleFree` with no arguments runs a guided first-run: prints the DevTools
  click-path, takes a paste, validates, connects
- Paste anything — **Copy as cURL**, a `Cookie:` header, a bare `PHPSESSID=…`,
  tab-separated DevTools rows, or JSON from a cookie-export extension
- `-IdSchool` is now **optional** — recovered from a pasted cURL body, or read from the
  signed-in page's `usertab_current_idschool`
- `-SaveCookie` persists the working cookie to `~/.mosylefreekit/cookie.txt` (mode 0600);
  later runs find it, along with `$env:MOSYLEFREEKIT_COOKIE` and `./secrets/cookie.txt`
- Connect failures now say what to do: rejected cookie, undetectable school, and
  wrong-school-slug are distinct errors
- Warns when a paste contains neither `PHPSESSID` nor `credentials`
- Non-interactive shells get a clear throw instead of a hang

### Reference docs
- New [docs/ENDPOINTS.md](docs/ENDPOINTS.md) — every mapped Free operation with its
  `mapping`/`operation` pair, body fields, the cmdlet that drives it, and the traps
  (soft `OK`, the `bullk_` typo, `command_status` vs `status`, `idcart` needing an array)
- `tools/capture-ui-network.js` folded in from the retired PHP bridge spike: records the
  Mosyle UI's own fetch/XHR traffic so new operations can be mapped from the Console

### Repo hygiene
- No tenant identifiers, device serials, or session cookies are committed
- `smoke-live.ps1` takes an explicit `-SerialNumber` / gitignored allowlist file — it
  ships with no device list of its own
- README documents the unsupported-endpoint, terms, and soft-`OK` caveats up front

## 0.4.3-alpha

### Platforms (best-effort)
- Fix `Get-MosyleFreeDevice` StrictMode crash on empty OS lists (`mac` / `tvos` / `visionos` with `devices:[]`)
- Docs: [docs/LIMITS.md](docs/LIMITS.md) — iOS validated; mac/tvOS/visionOS same bus, command delivery untested without devices
- Lost Mode help notes iOS-named ops are best-effort on other platforms

## 0.4.2-alpha

### Polish
- `-Verify` settles and retries (`-VerifySettleMs`, `-VerifyAttempts`) so late Commands rows (e.g. Restart OS) are not missed
- Broader verify label matching for Restart / Shutdown / Lock / SendPush
- Docs: [docs/LIMITS.md](docs/LIMITS.md) — soft-OK traps, supervised vs unsupervised, Shared Device Groups

## 0.4.1-alpha

### Shared Device Groups
- `Get-MosyleFreeSharedDeviceGroup` — list name ↔ GroupId
- `New-MosyleFreeSharedDeviceGroup` / `Remove-MosyleFreeSharedDeviceGroup` — create/delete groups
- `Add-MosyleFreeDeviceSharedGroup` / `Remove-MosyleFreeDeviceSharedGroup` — device membership (`idcart=[N]`)
- `Set-MosyleFreeDeviceLimbo`

### Live (the Free test tenant)
- Supervised ASM: rename, Lock+message, Lost Mode on/off/sound, Restart, Wipe, Shutdown, tags, Shared Group assign
- Stale allowlist: Lock queue smoke (16 serials)

## 0.4.0-alpha

- Auth docs (`credentials` + `PHPSESSID`)
- `Remove-MosyleFreeDeviceTag`, `Set-MosyleFreeDeviceAccount`
- SendPush / UpdateInfo
- Full allowlist smoke script
