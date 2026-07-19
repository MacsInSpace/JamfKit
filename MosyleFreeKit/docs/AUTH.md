# MosyleFreeKit authentication (Free UI)

Free schools have **no** `managerapi.mosyle.com` access token. This module reuses the same
web session a signed-in browser holds on `https://myschool.mosyle.com/`.

## Quick start

```powershell
Connect-MosyleFree
```

That's it. With no arguments it prints the click-path, waits for a paste, works out the
school slug, validates the session, and connects. Add `-SaveCookie` and later runs pick the
cookie up on their own.

## What to paste

Any of these — the module detects the format:

| Format | Where it comes from |
|--------|--------------------|
| **Copy as cURL** (recommended) | DevTools → Network → right-click a request → Copy → Copy as cURL |
| `Cookie: PHPSESSID=…; credentials=…` | DevTools → Network → Request Headers |
| `PHPSESSID=…` | a single cookie value |
| Tab-separated rows | DevTools → Application → Cookies, select rows, copy |
| `[{"name":"PHPSESSID","value":"…"}]` | a cookie-export extension |

**Copy as cURL is the easiest** because the request body carries
`usertab_current_idschool`, so `-IdSchool` is recovered for you.

> Mosyle's session cookies are **HttpOnly** — they never appear in `document.cookie`.
> They have to come from DevTools or an export add-on.

## Cookie types

| Cookie | Domain | Role |
|--------|--------|------|
| `credentials` | `.mosyle.com` | JWT issued at login. Connect exchanges it for a PHP session. |
| `PHPSESSID` | `.mosyle.com` / myschool | Classic PHP session. Required for most `Controller/mapping.php` posts (401 without it). |

Either one usually gets you in; both is safest.

## Where the cookie is read from

When you pass neither `-Cookie` nor `-CookieFile`, Connect looks in order:

1. `$env:MOSYLEFREEKIT_COOKIE`
2. `./secrets/cookie.txt`
3. `~/.mosylefreekit/cookie.txt` ← where `-SaveCookie` writes (mode `0600`)

If none exist it falls back to the interactive walkthrough.

## What Connect does

1. Parses whatever you pasted into a cookie table.
2. Loads it into a `WebRequestSession` (URI-based jar, so `.mosyle.com` JWTs are sent).
3. **GET /** — Mosyle usually responds `Set-Cookie: PHPSESSID=…`, which lands in the jar,
   and the returned page carries the school slug.
4. Probes `devices_list_ajax.php` (unless `-SkipValidation`) to confirm school + OS work.

Optional `-AdminCredential` stores the Mosyle admin password for ops that raise
`newConfirmDialogSecurity` (Restart / Lock / Wipe / Lost Mode). Free sometimes accepts
mapping posts without it, but the UI normally requires it.

## Non-interactive / CI

```powershell
$env:MOSYLEFREEKIT_COOKIE = '/path/to/cookie.txt'
Connect-MosyleFree -IdSchool yourschool -Os ios
```

With no TTY the walkthrough is skipped and Connect throws rather than hanging.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `returned the login page` | Cookie expired or from another browser profile. Grab a fresh one. |
| `Could not detect the school slug` | Pass `-IdSchool` explicitly. |
| `device list returned an error` | The slug doesn't match the login you used. |
| `Neither PHPSESSID nor credentials` (warning) | You copied the wrong header or row. |

## Keep the cookie out of the repo

A session cookie is a live credential — anyone holding it is you, until it expires.
`secrets/` and `~/.mosylefreekit/` are gitignored; don't paste cookies into issues,
scripts, or commit messages.

## Live smoke

```powershell
./tools/smoke-live.ps1 -IdSchool yourschool -SerialNumber ABCD1234EFGH
```

There is no built-in device list — pass `-SerialNumber`, or put one serial per line in
`tools/smoke-allowlist.txt` (gitignored). **Only list devices you administer.**
Wipe / Lost Mode are deliberately not in smoke.

Operational limits (supervised vs unsupervised, Shared Device Groups): [LIMITS.md](LIMITS.md).

## Not this module

| Auth | Product |
|------|---------|
| JWT + accessToken → `managerapi.mosyle.com/v2` | **MosyleKit** (paid) |
