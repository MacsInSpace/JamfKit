# MosyleFreeKit root module (development loader).
# Release build flattens Public/ and Private/ into a single .psm1.

Set-StrictMode -Version 3.0

$script:DefaultMosyleFreeSession = $null

$private = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private') -Filter '*.ps1' -ErrorAction Ignore)
$public = @(Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public') -Filter '*.ps1' -ErrorAction Ignore)

foreach ($file in ($private + $public)) {
    . $file.FullName
}

Export-ModuleMember -Function $public.BaseName
