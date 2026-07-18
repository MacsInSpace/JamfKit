# JamfProKit

A modern, cross-platform PowerShell 7 module for the [Jamf Pro](https://www.jamf.com/products/jamf-pro/) API — built for 2026, not ported from 2019.

- **OAuth client credentials first.** API Roles and Clients is the primary auth path (basic auth against the Classic API was removed in Jamf Pro 11.17); user-account bearer tokens are fully supported too, with automatic keep-alive and renewal either way. Connect once, never think about tokens again.
- **One hardened request engine.** Both API families — the modern Jamf Pro API (JSON) and the Classic API (XML) — behind a single pipeline with automatic retry on 429/5xx (honoring `Retry-After`), exponential backoff with jitter, one-shot token refresh on 401, correct pagination, and Jamf Cloud sticky-session cookie handling.
- **MUT-style bulk operations, scriptable.** [The MUT](https://github.com/jamf/mut)'s CSV templates pipe *directly* into `Update-JamfComputer` — the parameter aliases match the template headers, and MUT semantics are honored (blank = unchanged, `CLEAR!` = wipe, site unassign via `-1`). Plus what a GUI can't give you: `-WhatIf` previews, per-row result objects, and failure export for retry runs.
- **Strict-mode clean, macOS-native.** Developed and tested on macOS under `Set-StrictMode -Version 3.0`. PowerShell 7.4+, `Core` edition only. CI runs macOS, Linux and Windows.
- **Full API surface via the escape hatch.** `Invoke-JamfApi` reaches any endpoint on either API with all the plumbing included.

## Quick start

```powershell
# OAuth client credentials (recommended — create one under Settings > API Roles and Clients)
Connect-JamfPro -Url https://acme.jamfcloud.com -ClientId $id -ClientSecret (Get-Secret JamfPro)

# or a user account
Connect-JamfPro -Url https://acme.jamfcloud.com -Credential (Get-Credential)

Get-JamfProVersion
Get-JamfComputer -Filter 'operatingSystem.version=lt=15.0' -Section GENERAL,OPERATING_SYSTEM
Get-JamfComputer -SerialNumber C02ABC123XYZ -Section ALL
```

### Bulk updates (the MUT workflow)

```powershell
# Preview a MUT computer template without touching anything
Import-Csv ./ComputerTemplate.csv | Update-JamfComputer -WhatIf

# Run it, capture per-row results, export failures for a retry pass
$results = Import-Csv ./ComputerTemplate.csv | Update-JamfComputer -ErrorAction SilentlyContinue
$results | Where-Object Status -eq 'Failed' | Export-Csv ./retry.csv

# All three MUT templates work — mobile devices chain the enforce-name PATCH automatically,
# and EA_<id> columns are picked up from the CSV
Import-Csv ./MobileDeviceTemplate.csv | Update-JamfMobileDevice
Import-Csv ./UserTemplate.csv | Update-JamfUser

# Static group membership: add, remove or replace — serials or IDs, auto-detected
Set-JamfStaticGroupMember -GroupId 15 -Add C02AAA111, C02BBB222
Set-JamfStaticGroupMember -GroupId 8 -Type User -Replace (Import-Csv users.csv).Username

# PreStage scope with automatic versionLock conflict retry
Set-JamfPrestageScope -PrestageId 3 -Add C02AAA111, C02BBB222
```

### Anything the module doesn't type yet

```powershell
Invoke-JamfApi -Path 'api/v1/buildings'
Invoke-JamfApi -Method POST -Path 'api/v1/buildings' -Body @{ name = 'HQ' }
Invoke-JamfApi -Method PUT -Path 'JSSResource/departments/id/3' -Body '<department><name>IT</name></department>'
```

## Cmdlets (v0.1)

| Area | Cmdlets |
|---|---|
| Session | `Connect-JamfPro`, `Disconnect-JamfPro`, `Get-JamfSession` |
| Escape hatch | `Invoke-JamfApi` |
| Inventory | `Get-JamfComputer`, `Get-JamfMobileDevice`, `Get-JamfProVersion` |
| Scripts | `Get-JamfScript`, `New-JamfScript`, `Set-JamfScript`, `Remove-JamfScript` |
| Policies | `Get-JamfPolicy` |
| Bulk (MUT) | `Update-JamfComputer`, `Update-JamfMobileDevice`, `Update-JamfUser`, `Set-JamfStaticGroupMember`, `Set-JamfPrestageScope` |

All destructive verbs support `-WhatIf`/`-Confirm`. All cmdlets accept `-Session` for multi-server work; without it they use the default session from the last `Connect-JamfPro`.

## Roadmap

- Typed CRUD for groups, categories, buildings, departments, extension attributes, packages (incl. JCDS2 upload), prestages, MDM commands, LAPS
- Spec-driven generic cmdlets fed by your instance's live OpenAPI schema (`/api/schema`) with tab completion
- Jamf Platform API gateway auth (`auth_provider: platform`)
- Throttled parallel bulk mode
- `JamfSchoolKit` sibling module

## Development

```powershell
./build.ps1            # analyze + test + package
./build.ps1 -Test      # just Pester
./build.ps1 -Package   # flatten to dist/JamfProKit
```

Source layout: one function per file under `src/JamfProKit/{Public,Private}`; the release build flattens to a single `.psm1`. Tests are Pester 5 with all HTTP mocked at a single seam (`Invoke-JamfHttp`) — the suite runs with no network and no Jamf server.

## Acknowledgements

JamfProKit is a from-scratch implementation, but it stands on the shoulders of the community projects that mapped this territory first:

- [The MUT](https://github.com/jamf/mut) (Mike Levenick) — the bulk-update workflow, CSV template formats and `CLEAR!` semantics that `Update-JamfComputer` deliberately remains compatible with
- [JamfPSPro](https://github.com/TrustyTristan/JamfPSPro) (Tristan Brazier) — the spec-driven coverage architecture that inspires our generic layer
- [Jamf-Pro-Powershell](https://github.com/cybertunnel/Jamf-Pro-Powershell) (Tyler Morgan) — ideas around scope builders and parallel paging
- [JamfUploader](https://github.com/grahampugh/jamf-upload) (Graham Pugh) — modern auth and API usage patterns, schema-driven endpoint resolution
- [terraform-provider-jamfpro](https://github.com/deploymenttheory/terraform-provider-jamfpro) (Deployment Theory) — the definition of feature-complete Jamf Pro resource coverage
- [JamfSync](https://github.com/jamf/JamfSync) (Jamf) — JCDS2 package upload mechanics
- [Replicator](https://github.com/jamf/Replicator) / [jamfcpr](https://github.com/BIG-RAT/jamfcpr) (Jamf PS / BIG-RAT) — endpoint coverage and migration patterns
- Kyle Ericson, Sd, Dan Snelson, mpanighetti, BIG-RAT and the wider Mac Admins community for years of shared Jamf API scripting

## License

[MIT](../LICENSE)
