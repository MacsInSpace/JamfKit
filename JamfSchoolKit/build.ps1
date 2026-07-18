<#
.SYNOPSIS
    Build script for JamfSchoolKit: analyze, test, and package.
.DESCRIPTION
    -Analyze   Run PSScriptAnalyzer against the source.
    -Test      Run the Pester suite.
    -Package   Flatten Public/Private into a single .psm1 under dist/JamfSchoolKit.
    No switches = do all three.
.EXAMPLE
    ./build.ps1 -Test
#>
[CmdletBinding()]
param(
    [switch] $Analyze,
    [switch] $Test,
    [switch] $Package
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$sourceRoot = Join-Path $repoRoot 'src' 'JamfSchoolKit'
$runAll = -not ($Analyze -or $Test -or $Package)

if ($Analyze -or $runAll) {
    Write-Host '== PSScriptAnalyzer ==' -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
    }
    $findings = Invoke-ScriptAnalyzer -Path $sourceRoot -Recurse -Settings (Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1')
    if ($findings) {
        $findings | Format-Table -AutoSize | Out-String | Write-Host
        throw "PSScriptAnalyzer reported $(@($findings).Count) finding(s)."
    }
    Write-Host 'Analyzer clean.' -ForegroundColor Green
}

if ($Test -or $runAll) {
    Write-Host '== Pester ==' -ForegroundColor Cyan
    if (-not (Get-Module -ListAvailable Pester | Where-Object { $_.Version -ge '5.0' })) {
        Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force
    }
    $config = New-PesterConfiguration
    $config.Run.Path = Join-Path $repoRoot 'tests'
    $config.Run.Exit = $true
    $config.Output.Verbosity = 'Detailed'
    Invoke-Pester -Configuration $config
}

if ($Package -or $runAll) {
    Write-Host '== Package ==' -ForegroundColor Cyan
    $distRoot = Join-Path $repoRoot 'dist' 'JamfSchoolKit'
    if (Test-Path $distRoot) { Remove-Item $distRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

    # Flatten all functions into a single .psm1 for load performance.
    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine('Set-StrictMode -Version 3.0')
    [void]$builder.AppendLine('$script:DefaultJamfSession = $null')
    [void]$builder.AppendLine()
    foreach ($folder in 'Private', 'Public') {
        foreach ($file in Get-ChildItem (Join-Path $sourceRoot $folder) -Filter '*.ps1' | Sort-Object Name) {
            [void]$builder.AppendLine((Get-Content $file.FullName -Raw))
        }
    }
    $manifest = Import-PowerShellDataFile (Join-Path $sourceRoot 'JamfSchoolKit.psd1')
    $exports = ($manifest.FunctionsToExport | ForEach-Object { "'$_'" }) -join ', '
    [void]$builder.AppendLine("Export-ModuleMember -Function @($exports)")

    Set-Content -Path (Join-Path $distRoot 'JamfSchoolKit.psm1') -Value $builder.ToString() -Encoding utf8BOM
    Copy-Item (Join-Path $sourceRoot 'JamfSchoolKit.psd1') $distRoot

    # Sanity check: the packaged module must import and export what the manifest says.
    $job = Start-Job -ScriptBlock {
        param($path)
        Import-Module $path -Force
        (Get-Module JamfSchoolKit).ExportedFunctions.Keys
    } -ArgumentList (Join-Path $distRoot 'JamfSchoolKit.psd1')
    $exported = $job | Wait-Job | Receive-Job
    $job | Remove-Job
    $missing = @($manifest.FunctionsToExport | Where-Object { $_ -notin $exported })
    if ($missing.Count -gt 0) {
        throw "Packaged module failed to export: $($missing -join ', ')"
    }
    Write-Host "Packaged to $distRoot ($(@($exported).Count) functions)." -ForegroundColor Green
}
