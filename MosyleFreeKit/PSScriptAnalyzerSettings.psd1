@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Write-Host is used only in build.ps1 (not module source); listed defensively.
        'PSAvoidUsingWriteHost'
        # Source files are UTF-8; BOM enforcement is noisy across editors.
        'PSUseBOMForUnicodeEncodedFile'
    )
    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
