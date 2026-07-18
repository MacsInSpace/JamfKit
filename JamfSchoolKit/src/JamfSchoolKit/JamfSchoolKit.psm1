# JamfSchoolKit root module (development loader).
# The release build flattens Public/ and Private/ into a single .psm1; this file
# dot-sources them individually so the module is directly usable from source.

Set-StrictMode -Version 3.0

# Module-scoped state: the default session used when cmdlets are called without -Session.
$script:DefaultJamfSchoolSession = $null

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction Ignore)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction Ignore)

foreach ($file in ($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName
