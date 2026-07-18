# Changelog

All notable changes to JamfSchoolKit are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0-alpha] - 2026-07-18

### Added
- Session core: `Connect-JamfSchool` (Network ID + API key Basic auth,
  SecretManagement-friendly), `Disconnect-JamfSchool`, `Get-JamfSchoolSession`.
- Hardened request engine: `X-Server-Protocol-Version` always sent (default 3
  — the API silently degrades to v1 shapes without it), retry with backoff
  honoring `Retry-After`, normalized errors surfacing the API's
  message/reason, guard for HTTP-200-but-failed responses (UnlockFailed).
- Devices: `Get-JamfSchoolDevice` (server-side filters, string-boolean
  handling), `Invoke-JamfSchoolDeviceCommand` (Restart/Wipe/Refresh/Restore/
  Unenroll/ClearActivationLock), `Set-JamfSchoolDeviceOwner` (user-0 clear
  convention), `Remove-JamfSchoolDevice`.
- Device groups: `Get-JamfSchoolDeviceGroup` (capital-D list envelope
  handled), `Set-JamfSchoolDeviceGroupMember` (documented groupId/udids
  payload).
- Users: full CRUD + dedicated password endpoint + `memberOf` mixing group
  IDs and names; `Get-JamfSchoolUserGroup` with ACLs.
- Classes: full CRUD at protocol v3, user assignment with the API's
  string-ID requirement handled, query-string removal (`students=all`),
  class device listing.
- `Invoke-JamfSchoolApi` escape hatch; Pester suite (20 tests, fully
  mocked); cross-platform CI job; flattening build script.
