function Update-JamfUser {
    <#
    .SYNOPSIS
        Updates user records — drop-in replacement for The MUT's user template, as a
        pipeline cmdlet.
    .DESCRIPTION
        Updates users via the Classic API. MUT compatibility: parameter aliases match
        the MUT user CSV template headers, so the template pipes straight in,
        including EA_<id> columns:

            Import-Csv ./UserTemplate.csv | Update-JamfUser -WhatIf

        Identifier heuristics follow The MUT: an all-digit Current Username is treated
        as a Jamf user ID unless -NumericIdentifiersAreNames is set (The MUT's
        "My Usernames are Ints" option for environments with numeric usernames).

        MUT semantics: blank = leave unchanged, CLEAR! = wipe. For LDAP Server ID and
        Site, CLEAR! unassigns via -1. Email updates both email and email_address, as
        the Classic API expects.
    .PARAMETER LdapServerId
        Numeric LDAP server ID to bind the user to; CLEAR! unassigns from all.
    .EXAMPLE
        Update-JamfUser -Username jappleseed -EmailAddress j.appleseed@acme.com
    .EXAMPLE
        Import-Csv ./UserTemplate.csv | Update-JamfUser
    .EXAMPLE
        Update-JamfUser -Username 100234 -NumericIdentifiersAreNames -FullName 'Test Student'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Name')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Name', ValueFromPipelineByPropertyName)]
        [Alias('Current Username')]
        [string] $Username,

        [Parameter(Mandatory, ParameterSetName = 'Id', ValueFromPipelineByPropertyName)]
        [int] $Id,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('New Username')]
        [string] $NewUsername,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Full Name')]
        [string] $FullName,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Email Address')]
        [string] $EmailAddress,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Phone Number')]
        [string] $PhoneNumber,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Position,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('LDAP Server ID')]
        [string] $LdapServerId,

        [Parameter(ValueFromPipelineByPropertyName)] [Alias('Site (ID or Name)')]
        [string] $Site,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Managed Apple ID (Requires Jamf Pro 10.15+)', 'Managed Apple ID')]
        [string] $ManagedAppleId,

        # Treat an all-digit Current Username as a username, not a Jamf user ID
        # (The MUT's "My Usernames are Ints" setting).
        [switch] $NumericIdentifiersAreNames,

        [hashtable] $ExtensionAttribute,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject,

        [PSTypeName('JamfProKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSession -Session $Session
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Id') {
            $identifier = "id/$Id"
            $identityLabel = "id $Id"
        }
        else {
            $numericId = 0
            if (-not $NumericIdentifiersAreNames -and [int]::TryParse($Username, [ref]$numericId)) {
                $identifier = "id/$numericId"
            }
            else {
                $identifier = "name/$([uri]::EscapeDataString($Username))"
            }
            $identityLabel = $Username
        }

        $body = [ordered]@{}
        $changes = [System.Collections.Generic.List[string]]::new()

        $flatMap = [ordered]@{
            NewUsername    = 'name'
            FullName       = 'full_name'
            PhoneNumber    = 'phone_number'
            Position       = 'position'
            ManagedAppleId = 'managed_apple_id'
        }
        foreach ($paramName in $flatMap.Keys) {
            if (-not $PSBoundParameters.ContainsKey($paramName)) { continue }
            $value = [string]$PSBoundParameters[$paramName]
            if ($value -eq '') { continue }                    # MUT: blank = unchanged
            if ($value -ceq 'CLEAR!') { $value = '' }          # MUT: CLEAR! = wipe
            $body[$flatMap[$paramName]] = $value
            [void]$changes.Add($paramName)
        }

        # The Classic API reads/writes both email fields; keep them in step.
        if ($PSBoundParameters.ContainsKey('EmailAddress') -and $EmailAddress -ne '') {
            $emailValue = if ($EmailAddress -ceq 'CLEAR!') { '' } else { $EmailAddress }
            $body['email'] = $emailValue
            $body['email_address'] = $emailValue
            [void]$changes.Add('EmailAddress')
        }

        if ($PSBoundParameters.ContainsKey('LdapServerId') -and $LdapServerId -ne '') {
            $ldapId = 0
            if ($LdapServerId -ceq 'CLEAR!') {
                $body['ldap_server'] = [ordered]@{ id = -1 }
                [void]$changes.Add('LdapServerId')
            }
            elseif ([int]::TryParse($LdapServerId, [ref]$ldapId)) {
                $body['ldap_server'] = [ordered]@{ id = $ldapId }
                [void]$changes.Add('LdapServerId')
            }
            else {
                Write-Warning "[$identityLabel] LDAP Server ID '$LdapServerId' is not a number or CLEAR!; skipping that field."
            }
        }

        if ($PSBoundParameters.ContainsKey('Site') -and $Site -ne '') {
            $siteId = 0
            if ($Site -ceq 'CLEAR!') {
                $body['sites'] = @([ordered]@{ id = -1 })
            }
            elseif ([int]::TryParse($Site, [ref]$siteId)) {
                $body['sites'] = @([ordered]@{ id = $siteId })
            }
            else {
                $body['sites'] = @([ordered]@{ name = $Site })
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
                $body['extension_attributes'] = @($eaList)
                [void]$changes.Add('ExtensionAttribute')
            }
        }

        if ($body.Count -eq 0) {
            Write-Verbose "[$identityLabel] No changes supplied; skipping."
            return
        }

        $xml = ConvertTo-JamfXml -RootElement 'user' -InputObject $body

        if ($PSCmdlet.ShouldProcess($identityLabel, "Update user ($($changes -join ', '))")) {
            try {
                Invoke-JamfRequest -Session $resolved -Method PUT -Path "JSSResource/users/$identifier" `
                    -Body $xml -Accept 'application/xml' | Out-Null
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
}
