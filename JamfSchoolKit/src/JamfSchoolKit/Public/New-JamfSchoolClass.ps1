function New-JamfSchoolClass {
    <#
    .SYNOPSIS
        Creates a class in Jamf School.
    .EXAMPLE
        New-JamfSchoolClass -Name 'Year 8 Science' -Teachers 113971 -Students 123, 456
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Description,

        [Parameter(ValueFromPipelineByPropertyName)]
        [int] $LocationId,

        [int[]] $Students,

        [int[]] $Teachers,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        $body = @{ name = $Name }
        if ($Description) { $body['description'] = $Description }
        if ($PSBoundParameters.ContainsKey('LocationId')) { $body['locationId'] = $LocationId }
        if ($null -ne $Students -and $Students.Count -gt 0) { $body['students'] = @($Students) }
        if ($null -ne $Teachers -and $Teachers.Count -gt 0) { $body['teachers'] = @($Teachers) }

        if ($PSCmdlet.ShouldProcess($Name, 'Create Jamf School class')) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method POST -Path 'classes' -Body $body -ProtocolVersion 3
            Assert-JamfSchoolResponseCode -Response $response -Context "Create class $Name" | Out-Null
            $newUuid = Select-JamfSchoolResult -Response $response -Property 'uuid'
            if ($newUuid -is [string] -and $newUuid) {
                Get-JamfSchoolClass -Session $resolved -Uuid $newUuid
            }
            else {
                $response
            }
        }
    }
}
