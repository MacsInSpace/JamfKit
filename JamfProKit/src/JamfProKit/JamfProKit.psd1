@{
    RootModule           = 'JamfProKit.psm1'
    ModuleVersion        = '0.2.0'
    GUID                 = 'b7f3d9e4-2a61-4c8f-9d05-8e1a6f4c3b27'
    Author               = 'Craig Hair'
    CompanyName          = 'Unknown'
    Copyright            = '(c) 2026 Craig Hair. MIT License.'
    Description          = 'A modern, cross-platform PowerShell 7 module for the Jamf Pro API. OAuth client-credentials first, strict-mode clean, with MUT-style CSV bulk operations. Covers both the Jamf Pro API (JSON) and Classic API (XML) behind one hardened request engine.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Connect-JamfPro'
        'Disconnect-JamfPro'
        'Get-JamfSession'
        'Invoke-JamfApi'
        'Get-JamfProVersion'
        'Get-JamfComputer'
        'Get-JamfMobileDevice'
        'Get-JamfScript'
        'New-JamfScript'
        'Set-JamfScript'
        'Remove-JamfScript'
        'Get-JamfPolicy'
        'Update-JamfComputer'
        'Update-JamfMobileDevice'
        'Update-JamfUser'
        'Set-JamfPrestageScope'
        'Set-JamfStaticGroupMember'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Jamf', 'JamfPro', 'MDM', 'Apple', 'macOS', 'iOS', 'MacAdmins', 'REST', 'API')
            LicenseUri   = 'https://github.com/MacsInSpace/JamfKit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/MacsInSpace/JamfKit'
            ReleaseNotes = 'Initial scaffold: session/auth core (OAuth client credentials + user bearer), request engine with retry/backoff, paging, Classic XML support, first typed cmdlets and MUT-compatible bulk updates.'
            Prerelease   = 'alpha'
        }
    }
}
