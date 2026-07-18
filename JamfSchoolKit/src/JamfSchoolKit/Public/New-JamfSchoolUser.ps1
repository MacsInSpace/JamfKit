function New-JamfSchoolUser {
    <#
    .SYNOPSIS
        Creates a user in Jamf School.
    .PARAMETER MemberOf
        Group memberships: a mix of group IDs and/or group names — unknown names are
        created as new groups by the API.
    .PARAMETER ExcludeFromRestrictions
        The API's 'exclude' flag: don't apply Teacher app restrictions to this user.
    .EXAMPLE
        New-JamfSchoolUser -Username jappleseed -Password (Get-Secret TempPw) -Email ja@school.org `
            -FirstName Johnny -LastName Appleseed -MemberOf 'Students', 12
    .EXAMPLE
        Import-Csv new-students.csv | New-JamfSchoolUser
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Username,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [securestring] $Password,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Email,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $FirstName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $LastName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Domain,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Notes,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int] $LocationId,

        [Parameter(ValueFromPipelineByPropertyName)]
        [object[]] $MemberOf,

        [switch] $StorePassword,

        [switch] $ExcludeFromRestrictions,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        $body = @{
            username  = $Username
            password  = (ConvertFrom-SecureString -SecureString $Password -AsPlainText)
            email     = $Email
            firstName = $FirstName
            lastName  = $LastName
        }
        if ($Domain) { $body['domain'] = $Domain }
        if ($Notes) { $body['notes'] = $Notes }
        if ($PSBoundParameters.ContainsKey('LocationId')) { $body['locationId'] = $LocationId }
        if ($null -ne $MemberOf -and $MemberOf.Count -gt 0) { $body['memberOf'] = @($MemberOf) }
        if ($StorePassword) { $body['storePassword'] = $true }
        if ($ExcludeFromRestrictions) { $body['exclude'] = $true }

        if ($PSCmdlet.ShouldProcess($Username, 'Create Jamf School user')) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method POST -Path 'users' -Body $body
            Assert-JamfSchoolResponseCode -Response $response -Context "Create user $Username" | Out-Null
            $newId = Select-JamfSchoolResult -Response $response -Property 'id'
            if ($null -ne $newId -and "$newId" -match '^\d+$') {
                Get-JamfSchoolUser -Session $resolved -Id ([int]$newId)
            }
            else {
                $response
            }
        }
    }
}
