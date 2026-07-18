function Set-JamfSchoolClass {
    <#
    .SYNOPSIS
        Updates a class in Jamf School: rename/re-describe, assign users, remove users.
    .DESCRIPTION
        Three underlying endpoints, orchestrated by what you supply:
          -Name/-Description         -> PUT /classes/{uuid}
          -Students/-Teachers        -> PUT /classes/{uuid}/users (assignment; the API
                                        expects user IDs as strings — handled for you)
          -RemoveStudents/-RemoveTeachers -> DELETE /classes/{uuid}/users (query-string
                                        driven; pass 'all' to clear a role entirely)
    .EXAMPLE
        Set-JamfSchoolClass -Uuid $uuid -Name 'Year 9 Science'
    .EXAMPLE
        Set-JamfSchoolClass -Uuid $uuid -Students 123, 456 -Teachers 113971
    .EXAMPLE
        Set-JamfSchoolClass -Uuid $uuid -RemoveStudents all
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Uuid,

        [string] $Name,

        [string] $Description,

        [int[]] $Students,

        [int[]] $Teachers,

        # Student IDs to remove, or 'all'.
        [string[]] $RemoveStudents,

        # Teacher IDs to remove, or 'all'.
        [string[]] $RemoveTeachers,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        $details = @{}
        if ($PSBoundParameters.ContainsKey('Name')) { $details['name'] = $Name }
        if ($PSBoundParameters.ContainsKey('Description')) { $details['description'] = $Description }
        if ($details.Count -gt 0 -and $PSCmdlet.ShouldProcess("Class $Uuid", "Update ($($details.Keys -join ', '))")) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method PUT -Path "classes/$Uuid" -Body $details -ProtocolVersion 3
            Assert-JamfSchoolResponseCode -Response $response -Context "Update class $Uuid" | Out-Null
        }

        if (($null -ne $Students -and $Students.Count -gt 0) -or ($null -ne $Teachers -and $Teachers.Count -gt 0)) {
            # The API expects user IDs as strings in this payload.
            $assignment = @{}
            if ($null -ne $Students -and $Students.Count -gt 0) { $assignment['students'] = @($Students | ForEach-Object { [string]$_ }) }
            if ($null -ne $Teachers -and $Teachers.Count -gt 0) { $assignment['teachers'] = @($Teachers | ForEach-Object { [string]$_ }) }
            if ($PSCmdlet.ShouldProcess("Class $Uuid", "Assign users ($($assignment.Keys -join ', '))")) {
                $response = Invoke-JamfSchoolRequest -Session $resolved -Method PUT -Path "classes/$Uuid/users" -Body $assignment -ProtocolVersion 3
                Assert-JamfSchoolResponseCode -Response $response -Context "Assign users to class $Uuid" | Out-Null
            }
        }

        if ($RemoveStudents -or $RemoveTeachers) {
            $query = @{}
            if ($RemoveStudents) { $query['students'] = ($RemoveStudents -join ',') }
            if ($RemoveTeachers) { $query['teachers'] = ($RemoveTeachers -join ',') }
            if ($PSCmdlet.ShouldProcess("Class $Uuid", "Remove users ($($query.Keys -join ', '))")) {
                $response = Invoke-JamfSchoolRequest -Session $resolved -Method DELETE -Path "classes/$Uuid/users" -Query $query -ProtocolVersion 3
                Assert-JamfSchoolResponseCode -Response $response -Context "Remove users from class $Uuid" | Out-Null
            }
        }
    }
}
