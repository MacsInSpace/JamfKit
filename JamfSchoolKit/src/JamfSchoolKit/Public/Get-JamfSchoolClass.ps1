function Get-JamfSchoolClass {
    <#
    .SYNOPSIS
        Gets classes from Jamf School.
    .DESCRIPTION
        Lists all classes, fetches one by -Uuid (including its students and teachers),
        or lists a class's devices with -Devices.
    .EXAMPLE
        Get-JamfSchoolClass
    .EXAMPLE
        Get-JamfSchoolClass -Uuid $uuid
    .EXAMPLE
        Get-JamfSchoolClass -Uuid $uuid -Devices
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Uuid', Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Uuid,

        [Parameter(ParameterSetName = 'Uuid')]
        [switch] $Devices,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Uuid') {
            if ($Devices) {
                $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "classes/$Uuid/devices" -ProtocolVersion 3
                return (Select-JamfSchoolResult -Response $response -Property 'devices')
            }
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "classes/$Uuid" -ProtocolVersion 3
            return (Select-JamfSchoolResult -Response $response -Property 'class')
        }
        $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path 'classes' -ProtocolVersion 3
        Select-JamfSchoolResult -Response $response -Property 'classes'
    }
}
