function Update-JamfMobileDevice {
    <#
    .SYNOPSIS
        Updates mobile device inventory attributes — drop-in replacement for The MUT's
        mobile device template, as a pipeline cmdlet.
    .DESCRIPTION
        Inventory, location and purchasing fields are written via the Classic API.
        Display Name and Enforce Name are written via the Jamf Pro API
        (PATCH /api/v2/mobile-devices/{id}), exactly as The MUT does — the Classic
        mobile device record cannot enforce names. When both kinds of change are in
        one row, the Classic update runs first and the device ID is taken from its
        response; a name-only change resolves the ID by serial number.

        MUT compatibility: parameter aliases match the MUT mobile device CSV template
        headers, so the template pipes straight in, including EA_<id> columns:

            Import-Csv ./MobileDeviceTemplate.csv | Update-JamfMobileDevice -WhatIf

        MUT semantics: blank = leave unchanged, CLEAR! = wipe (Site unassigns via -1).
        Failures are per-row non-terminating errors with result objects for retry.
    .PARAMETER EnforceName
        'true' enforces the Display Name on the device (Jamf Pro 10.33+); 'false'
        stops enforcing. Blank leaves the setting unchanged.
    .EXAMPLE
        Update-JamfMobileDevice -SerialNumber F9FXH12ABC -AssetTag 'IPAD-042' -Room 'Lab 2'
    .EXAMPLE
        Import-Csv ./MobileDeviceTemplate.csv | Update-JamfMobileDevice
    .EXAMPLE
        Update-JamfMobileDevice -SerialNumber F9FXH12ABC -DisplayName 'Cart-01-iPad-07' -EnforceName true
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Serial')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'AirplayPassword',
        Justification = 'The tvOS AirPlay password is an inventory data field from the MUT CSV template, not an authentication credential.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'Username is the assigned-user inventory field and AirplayPassword is a tvOS data field; neither is a credential.')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Serial', ValueFromPipelineByPropertyName)]
        [Alias('Serial', 'Mobile Device Serial')]
        [string] $SerialNumber,

        [Parameter(Mandatory, ParameterSetName = 'Id', ValueFromPipelineByPropertyName)]
        [int] $Id,

        # --- Jamf Pro API (PATCH) fields ---
        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Display Name')]
        [string] $DisplayName,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Enforce Name')]
        [string] $EnforceName,

        # --- general ---
        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Asset Tag')]
        [string] $AssetTag,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Airplay Password (tvOS Only)', 'Airplay Password')]
        [string] $AirplayPassword,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Site (ID or Name)')]
        [string] $Site,

        # --- location ---
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Username,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Real Name')]
        [string] $RealName,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Email Address')]
        [string] $EmailAddress,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Position,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Phone Number')]
        [string] $PhoneNumber,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Department,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Building,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Room,

        # --- purchasing ---
        [Parameter(ValueFromPipelineByPropertyName)] [Alias('PO Number')]
        [string] $PONumber,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Vendor,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Purchase Price')]
        [string] $PurchasePrice,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('PO Date')]
        [string] $PODate,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Warranty Expires')]
        [string] $WarrantyExpires,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Is Leased')]
        [string] $IsLeased,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Lease Expires')]
        [string] $LeaseExpires,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('AppleCare ID')]
        [string] $AppleCareId,

        [hashtable] $ExtensionAttribute,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [PSTypeName('JamfProKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSession -Session $Session

        $fieldMap = @{
            AssetTag        = @('general', 'asset_tag')
            AirplayPassword = @('general', 'airplay_password')
            Username        = @('location', 'username')
            RealName        = @('location', 'real_name')
            EmailAddress    = @('location', 'email_address')
            Position        = @('location', 'position')
            PhoneNumber     = @('location', 'phone_number')
            Department      = @('location', 'department')
            Building        = @('location', 'building')
            Room            = @('location', 'room')
            PONumber        = @('purchasing', 'po_number')
            Vendor          = @('purchasing', 'vendor')
            PurchasePrice   = @('purchasing', 'purchase_price')
            PODate          = @('purchasing', 'po_date')
            WarrantyExpires = @('purchasing', 'warranty_expires')
            IsLeased        = @('purchasing', 'is_leased')
            LeaseExpires    = @('purchasing', 'lease_expires')
            AppleCareId     = @('purchasing', 'applecare_id')
        }
    }

    process {
        $identifier = if ($PSCmdlet.ParameterSetName -eq 'Id') { "id/$Id" } else { "serialnumber/$([uri]::EscapeDataString($SerialNumber))" }
        $identityLabel = if ($PSCmdlet.ParameterSetName -eq 'Id') { "id $Id" } else { $SerialNumber }

        $sections = [ordered]@{}
        $changes = [System.Collections.Generic.List[string]]::new()

        foreach ($paramName in $fieldMap.Keys) {
            if (-not $PSBoundParameters.ContainsKey($paramName)) { continue }
            $value = [string]$PSBoundParameters[$paramName]
            if ($value -eq '') { continue }                    # MUT: blank = unchanged
            if ($value -ceq 'CLEAR!') { $value = '' }          # MUT: CLEAR! = wipe

            $sectionName, $elementName = $fieldMap[$paramName]
            if (-not $sections.Contains($sectionName)) { $sections[$sectionName] = [ordered]@{} }
            $sections[$sectionName][$elementName] = $value
            [void]$changes.Add($paramName)
        }

        if ($PSBoundParameters.ContainsKey('Site') -and $Site -ne '') {
            if (-not $sections.Contains('general')) { $sections['general'] = [ordered]@{} }
            $siteId = 0
            if ($Site -ceq 'CLEAR!') {
                $sections['general']['site'] = [ordered]@{ id = -1 }
            }
            elseif ([int]::TryParse($Site, [ref]$siteId)) {
                $sections['general']['site'] = [ordered]@{ id = $siteId }
            }
            else {
                $sections['general']['site'] = [ordered]@{ name = $Site }
            }
            [void]$changes.Add('Site')
        }

        $eaMerged = Merge-JamfExtensionAttributeInput -InputObject $InputObject -ExtensionAttribute $ExtensionAttribute
        if ($eaMerged.Count -gt 0) {
            $eaList = foreach ($key in ($eaMerged.Keys | Sort-Object)) {
                $eaValue = [string]$eaMerged[$key]
                if ($eaValue -eq '') { continue }
                if ($eaValue -ceq 'CLEAR!') { $eaValue = '' }
                [ordered]@{ id = [int]$key; value = $eaValue }
            }
            if (@($eaList).Count -gt 0) {
                $sections['extension_attributes'] = @($eaList)
                [void]$changes.Add('ExtensionAttribute')
            }
        }

        # Name/enforce-name go through the Jamf Pro API, like The MUT does.
        $patchBody = @{}
        if ($PSBoundParameters.ContainsKey('DisplayName') -and $DisplayName -ne '') {
            $patchBody['name'] = $DisplayName
            [void]$changes.Add('DisplayName')
        }
        if ($PSBoundParameters.ContainsKey('EnforceName') -and $EnforceName -ne '') {
            $enforceBool = $false
            if ([bool]::TryParse($EnforceName, [ref]$enforceBool)) {
                $patchBody['enforceName'] = $enforceBool
                [void]$changes.Add('EnforceName')
            }
            else {
                Write-Warning "[$identityLabel] EnforceName value '$EnforceName' is not true/false; skipping that field."
            }
        }

        if ($sections.Count -eq 0 -and $patchBody.Count -eq 0) {
            Write-Verbose "[$identityLabel] No changes supplied; skipping."
            return
        }

        if (-not $PSCmdlet.ShouldProcess($identityLabel, "Update mobile device ($($changes -join ', '))")) {
            return
        }

        try {
            $deviceId = if ($PSCmdlet.ParameterSetName -eq 'Id') { [string]$Id } else { $null }

            if ($sections.Count -gt 0) {
                $xml = ConvertTo-JamfXml -RootElement 'mobile_device' -InputObject $sections
                $classicResponse = Invoke-JamfRequest -Session $resolved -Method PUT `
                    -Path "JSSResource/mobiledevices/$identifier" -Body $xml -Accept 'application/xml'
                if (-not $deviceId -and $classicResponse -is [xml]) {
                    try { $deviceId = [string]$classicResponse.mobile_device.id } catch { $deviceId = $null }
                }
            }

            if ($patchBody.Count -gt 0) {
                if (-not $deviceId) {
                    $escaped = $SerialNumber -replace '"', ''
                    $found = @(Get-JamfPagedResult -Session $resolved -Path 'api/v2/mobile-devices' `
                        -Filter ('serialNumber=="{0}"' -f $escaped))
                    if ($found.Count -eq 1) { $deviceId = [string]$found[0].id }
                }
                if (-not $deviceId) {
                    throw "Could not resolve a unique device ID for '$identityLabel' to set the display name."
                }
                Invoke-JamfRequest -Session $resolved -Method PATCH -Path "api/v2/mobile-devices/$deviceId" `
                    -Body $patchBody | Out-Null
            }

            [pscustomobject]@{
                PSTypeName = 'JamfProKit.BulkResult'
                Identifier = $identityLabel
                Status     = 'Updated'
                Fields     = $changes -join ', '
                Error      = $null
            }
        }
        catch {
            [pscustomobject]@{
                PSTypeName = 'JamfProKit.BulkResult'
                Identifier = $identityLabel
                Status     = 'Failed'
                Fields     = $changes -join ', '
                Error      = $_.Exception.Message
            }
            Write-Error -Message "[$identityLabel] $($_.Exception.Message)" -TargetObject $identityLabel
        }
    }
}
