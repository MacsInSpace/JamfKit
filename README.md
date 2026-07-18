# JamfKit

Modern, cross-platform PowerShell 7 modules for the Jamf platform — built for 2026, not ported from 2019.

| Module | Status | Target |
|---|---|---|
| **[JamfProKit](JamfProKit/)** | v0.5.0-alpha | [Jamf Pro](https://www.jamf.com/products/jamf-pro/) — Jamf Pro API (JSON) + Classic API (XML) |
| **[JamfSchoolKit](JamfSchoolKit/)** | v0.1.0-alpha | [Jamf School](https://www.jamf.com/products/jamf-school/) — Jamf School API (first PowerShell module for it) |

Why two modules in one repo: the Jamf Pro and Jamf School APIs share nothing — different auth
(OAuth client credentials vs Network ID + API key), different versioning, different conventions —
so each product gets a module that fits its API properly. They live here together because they'll
share a common HTTP/retry/credential core, one issue tracker, and one release pipeline. Each
module installs independently from the PowerShell Gallery.

## Highlights (JamfProKit)

- **OAuth client credentials first** (API Roles and Clients), user bearer tokens too — automatic renewal either way
- **One hardened request engine**: retry with backoff honoring `Retry-After`, 401 token refresh, pagination, Jamf Cloud sticky sessions
- **MUT-style bulk operations**: [The MUT](https://github.com/jamf/mut)'s CSV templates pipe *directly* into `Update-JamfComputer`, with `-WhatIf` previews and per-row result objects the GUI never had
- **Strict-mode clean, macOS-native**, PowerShell 7.4+, CI on macOS/Linux/Windows

See the [JamfProKit README](JamfProKit/README.md) for the full tour, cmdlet list and roadmap,
including the acknowledgements to the community projects that mapped this territory first.

## License

[MIT](LICENSE)
