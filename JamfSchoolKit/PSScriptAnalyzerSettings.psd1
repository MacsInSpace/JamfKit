@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Write-Host is used only in build.ps1 (not module source); listed defensively.
        'PSAvoidUsingWriteHost'
    )
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
