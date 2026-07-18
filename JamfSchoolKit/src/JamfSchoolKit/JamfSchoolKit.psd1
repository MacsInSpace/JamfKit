@{
    RootModule           = 'JamfSchoolKit.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = '4c8e2f7a-9b13-4d6e-a250-3f7c1e8d9b42'
    Author               = 'Craig Hair'
    CompanyName          = 'Unknown'
    Copyright            = '(c) 2026 Craig Hair. MIT License.'
    Description          = 'A modern, cross-platform PowerShell 7 module for the Jamf School API. The first of its kind: typed cmdlets for devices, users, classes and groups over a hardened request engine with retry and protocol-version handling. Sibling of JamfProKit.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Connect-JamfSchool'
        'Disconnect-JamfSchool'
        'Get-JamfSchoolSession'
        'Invoke-JamfSchoolApi'
        'Get-JamfSchoolDevice'
        'Invoke-JamfSchoolDeviceCommand'
        'Set-JamfSchoolDeviceOwner'
        'Remove-JamfSchoolDevice'
        'Get-JamfSchoolDeviceGroup'
        'Set-JamfSchoolDeviceGroupMember'
        'Get-JamfSchoolUser'
        'New-JamfSchoolUser'
        'Set-JamfSchoolUser'
        'Remove-JamfSchoolUser'
        'Get-JamfSchoolUserGroup'
        'Get-JamfSchoolClass'
        'New-JamfSchoolClass'
        'Set-JamfSchoolClass'
        'Remove-JamfSchoolClass'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Jamf', 'JamfSchool', 'MDM', 'Apple', 'iPad', 'Education', 'MacAdmins', 'REST', 'API')
            LicenseUri   = 'https://github.com/MacsInSpace/JamfKit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/MacsInSpace/JamfKit'
            ReleaseNotes = 'Initial release: session core (Network ID + API key), hardened request engine with protocol-version header handling, typed cmdlets for devices (incl. MDM-style commands), users, classes and device/user groups.'
            Prerelease   = 'alpha'
        }
    }
}
