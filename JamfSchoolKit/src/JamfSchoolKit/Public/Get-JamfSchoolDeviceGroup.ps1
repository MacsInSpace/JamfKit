function Get-JamfSchoolDeviceGroup {
    <#
    .SYNOPSIS
        Gets device groups from Jamf School.
    .EXAMPLE
        Get-JamfSchoolDeviceGroup
    .EXAMPLE
        Get-JamfSchoolDeviceGroup -Id 12
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
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "devices/groups/$Id"
            return (Select-JamfSchoolResult -Response $response -Property 'deviceGroup')
        }
        $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path 'devices/groups'
        # The list envelope key is capital-D 'DeviceGroups'.
        Select-JamfSchoolResult -Response $response -Property 'DeviceGroups'
    }
}
