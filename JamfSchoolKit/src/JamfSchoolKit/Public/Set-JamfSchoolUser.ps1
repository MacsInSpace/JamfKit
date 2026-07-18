function Set-JamfSchoolUser {
    <#
    .SYNOPSIS
        Updates a user in Jamf School. Only the properties you supply change.
    .DESCRIPTION
        Field updates go to PUT /users/{id}; a -Password change uses the dedicated
        PUT /users/{id}/password endpoint. -MemberOf REPLACES group membership
        (IDs and/or names; unknown names are created).
    .EXAMPLE
        Set-JamfSchoolUser -Id 1234 -Email new.address@school.org
    .EXAMPLE
        Set-JamfSchoolUser -Id 1234 -Password (Get-Secret ResetPw)
    .EXAMPLE
        Set-JamfSchoolUser -Id 1234 -MemberOf 'Students', 'Year 8'
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [int] $Id,

        [string] $Username,

        [string] $Email,

        [string] $FirstName,

        [string] $LastName,

        [string] $Domain,

        [string] $Notes,

        [object[]] $MemberOf,

        [securestring] $Password,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
        $fieldMap = @{
            Username  = 'username'
            Email     = 'email'
            FirstName = 'firstName'
            LastName  = 'lastName'
            Domain    = 'domain'
            Notes     = 'notes'
        }
    }

    process {
        $body = @{}
        foreach ($paramName in $fieldMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $body[$fieldMap[$paramName]] = $PSBoundParameters[$paramName]
            }
        }
        if ($PSBoundParameters.ContainsKey('MemberOf')) { $body['memberOf'] = @($MemberOf) }

        if ($body.Count -gt 0 -and $PSCmdlet.ShouldProcess("User id $Id", "Update ($($body.Keys -join ', '))")) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method PUT -Path "users/$Id" -Body $body
            Assert-JamfSchoolResponseCode -Response $response -Context "Update user $Id" | Out-Null
        }

        if ($PSBoundParameters.ContainsKey('Password') -and $PSCmdlet.ShouldProcess("User id $Id", 'Set password')) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method PUT -Path "users/$Id/password" `
                -Body @{ password = (ConvertFrom-SecureString -SecureString $Password -AsPlainText) }
            Assert-JamfSchoolResponseCode -Response $response -Context "Set password for user $Id" | Out-Null
        }
    }
}
