# JamfProKit

A modern, cross-platform PowerShell 7 module for the [Jamf Pro](https://www.jamf.com/products/jamf-pro/) API — built for 2026, not ported from 2019.

Part of **[MDMKit](../)** — PowerShell 7 modules for Apple MDM platforms. Siblings:
[JamfSchoolKit](../JamfSchoolKit/), [MosyleKit](../MosyleKit/), [MosyleFreeKit](../MosyleFreeKit/).

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

### Groups and packages

```powershell
# Smart group from criteria (priorities auto-numbered)
New-JamfGroup -Name 'Pre-Sequoia Macs' -Smart -Criteria (
    New-JamfCriterion -Name 'Operating System Version' -SearchType 'less than' -Value '15.0'
)

# Upload a package: finds or creates the record by file name, uploads to JCDS,
# optionally waits for the server-side hash before you deploy
Publish-JamfPackage -Path ./Firefox-128.0.pkg -WaitForHash
Get-ChildItem ./out/*.pkg | ForEach-Object { Publish-JamfPackage -Path $_.FullName }
```

### The whole API, spec-driven

The generic layer reads your instance's own OpenAPI spec (`/api/schema`) on first use and
caches it per host + Jamf Pro version — so coverage tracks whatever your server runs,
including endpoints added after this module shipped. `-Resource` tab-completes.

```powershell
Get-JamfApiResource -Name '*enrollment*'        # discover what your instance offers
Get-JamfObject enrollment-customizations        # list (auto-paged), newest API version
Get-JamfObject webhooks -Id 5

$body = New-JamfObjectTemplate webhooks          # schema-accurate skeleton: every field,
$body.name = 'Inventory updated'                 # enums pre-filled, readOnly omitted
New-JamfObject webhooks -Body $body

Set-JamfObject mobile-devices -Id 31 -Body @{ name = 'Cart-01' }   # uses PATCH where documented
Remove-JamfObject webhooks -Id 5 -WhatIf
```

### Raw escape hatch

```powershell
Invoke-JamfApi -Path 'api/v1/buildings'
Invoke-JamfApi -Method POST -Path 'api/v1/buildings' -Body @{ name = 'HQ' }
Invoke-JamfApi -Method PUT -Path 'JSSResource/departments/id/3' -Body '<department><name>IT</name></department>'
```

## Cmdlets (v0.5)

| Area | Cmdlets |
|---|---|
| Session | `Connect-JamfPro`, `Disconnect-JamfPro`, `Get-JamfSession` |
| Escape hatch | `Invoke-JamfApi` |
| Inventory | `Get-JamfComputer`, `Get-JamfMobileDevice`, `Get-JamfProVersion` |
| Scripts | `Get-JamfScript`, `New-JamfScript`, `Set-JamfScript`, `Remove-JamfScript` |
| Categories | `Get-JamfCategory`, `New-JamfCategory`, `Set-JamfCategory`, `Remove-JamfCategory` |
| Groups | `Get-JamfGroup`, `New-JamfGroup`, `Set-JamfGroup`, `Remove-JamfGroup`, `New-JamfCriterion` |
| Packages | `Get-JamfPackage`, `New-JamfPackage`, `Set-JamfPackage`, `Remove-JamfPackage`, `Publish-JamfPackage` |
| Buildings / Departments | `Get/New/Set/Remove-JamfBuilding`, `Get/New/Set/Remove-JamfDepartment` |
| Extension attributes | `Get/New/Set/Remove-JamfExtensionAttribute` (computer + mobile device) |
| MDM | `Send-JamfMdmCommand`, `Invoke-JamfFrameworkRedeploy` |
| LAPS | `Get-JamfLapsAccount`, `Get-JamfLapsPassword`, `Get-JamfLapsSetting`, `Set-JamfLapsSetting` |
| Spec-driven (full API) | `Get-JamfObject`, `New-JamfObject`, `Set-JamfObject`, `Remove-JamfObject`, `New-JamfObjectTemplate`, `Get-JamfApiResource` |
| Policies | `Get-JamfPolicy` |
| Bulk (MUT) | `Update-JamfComputer`, `Update-JamfMobileDevice`, `Update-JamfUser`, `Set-JamfStaticGroupMember`, `Set-JamfPrestageScope` |

All destructive verbs support `-WhatIf`/`-Confirm`. All cmdlets accept `-Session` for multi-server work; without it they use the default session from the last `Connect-JamfPro`.

## Roadmap

- Typed CRUD for prestage enrollments, policies (write), configuration profiles
- Direct-to-S3 JCDS2 multipart upload (for very large packages / resumable transfers)
- Jamf Platform API gateway auth (`auth_provider: platform`)
- Throttled parallel bulk mode

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
