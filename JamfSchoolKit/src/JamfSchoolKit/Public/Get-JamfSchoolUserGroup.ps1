function Get-JamfSchoolUserGroup {
    <#
    .SYNOPSIS
        Gets user groups from Jamf School (including their Self Service / Teacher /
        Parent ACLs).
    .EXAMPLE
        Get-JamfSchoolUserGroup
    .EXAMPLE
        Get-JamfSchoolUserGroup -Id 12
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Id', Position = 0, ValueFromPipelineByPropertyName)]
        [int] $Id,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Id') {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "users/groups/$Id"
            return (Select-JamfSchoolResult -Response $response -Property 'group')
        }
        $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path 'users/groups'
        Select-JamfSchoolResult -Response $response -Property 'groups'
    }
}
