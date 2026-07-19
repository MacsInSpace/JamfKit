@{
    RootModule           = 'MosyleFreeKit.psm1'
    ModuleVersion        = '0.5.0'
    GUID                 = 'a7c3e9f2-4b1d-4e8a-9c5f-2d6b8a0e1f44'
    Author               = 'Craig Hair'
    CompanyName          = 'Unknown'
    Copyright            = '(c) 2026 Craig Hair. MIT License.'
    Description          = 'PowerShell 7 module for Mosyle Manager Free schools via the web UI session (myschool.mosyle.com). Not the paid managerapi.mosyle.com JWT API — that is MosyleKit. Sibling of MosyleKit / JamfProKit / JamfSchoolKit.'
    PowerShellVersion    = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport    = @(
        'Connect-MosyleFree'
        'Disconnect-MosyleFree'
        'Get-MosyleFreeSession'
        'Invoke-MosyleFreeUi'
        'Get-MosyleFreeDevice'
        'Get-MosyleFreeDeviceCommand'
        'Invoke-MosyleFreeDeviceCommand'
        'Invoke-MosyleFreeLostMode'
        'Set-MosyleFreeDeviceName'
        'Set-MosyleFreeDeviceTag'
        'Remove-MosyleFreeDeviceTag'
        'Set-MosyleFreeDeviceAccount'
        'Get-MosyleFreeSharedDeviceGroup'
        'New-MosyleFreeSharedDeviceGroup'
        'Remove-MosyleFreeSharedDeviceGroup'
        'Add-MosyleFreeDeviceSharedGroup'
        'Remove-MosyleFreeDeviceSharedGroup'
        'Set-MosyleFreeDeviceLimbo'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('Mosyle', 'MDM', 'Apple', 'iOS', 'Education', 'MacAdmins', 'Free', 'UI')
            LicenseUri   = 'https://github.com/MacsInSpace/MDMKit/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/MacsInSpace/MDMKit'
            ReleaseNotes = 'v0.5.0: guided Connect-MosyleFree with cURL/header/table/JSON cookie parsing, school auto-detection, -SaveCookie, and actionable connect errors.'
            Prerelease   = 'alpha'
        }
    }
}
