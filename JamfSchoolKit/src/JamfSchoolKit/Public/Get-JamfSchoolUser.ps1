function Get-JamfSchoolUser {
    <#
    .SYNOPSIS
        Gets users from Jamf School.
    .EXAMPLE
        Get-JamfSchoolUser
    .EXAMPLE
        Get-JamfSchoolUser -MemberOf 12 -HasDevice $true
    .EXAMPLE
        Get-JamfSchoolUser -Id 1234
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Id', Position = 0, ValueFromPipelineByPropertyName)]
        [int] $Id,

        [Parameter(ParameterSetName = 'List')]
        [int[]] $MemberOf,

        [Parameter(ParameterSetName = 'List')]
        [bool] $HasDevice,

        [Parameter(ParameterSetName = 'List')]
        [bool] $InTrash,

        [Parameter(ParameterSetName = 'List')]
        [string] $LocationId,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Id') {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "users/$Id"
            return (Select-JamfSchoolResult -Response $response -Property 'user')
        }

        $query = @{}
        if ($null -ne $MemberOf -and $MemberOf.Count -gt 0) { $query['memberOf'] = ($MemberOf -join ',') }
        if ($PSBoundParameters.ContainsKey('HasDevice')) { $query['hasDevice'] = $HasDevice.ToString().ToLowerInvariant() }
        if ($PSBoundParameters.ContainsKey('InTrash')) { $query['inTrash'] = $InTrash.ToString().ToLowerInvariant() }
        if ($LocationId) { $query['locationId'] = $LocationId }

        $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path 'users' -Query $query
        Select-JamfSchoolResult -Response $response -Property 'users'
    }
}
