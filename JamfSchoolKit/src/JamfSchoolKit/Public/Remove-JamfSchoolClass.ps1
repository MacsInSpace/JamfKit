function Remove-JamfSchoolClass {
    <#
    .SYNOPSIS
        Deletes a class from Jamf School (its associated user group survives).
    .EXAMPLE
        Remove-JamfSchoolClass -Uuid $uuid
    .EXAMPLE
        Get-JamfSchoolClass | Where-Object source -eq 'MANUAL' | Remove-JamfSchoolClass -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Uuid,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ShouldProcess("Class $Uuid", 'Delete Jamf School class')) {
            Invoke-JamfSchoolRequest -Session $resolved -Method DELETE -Path "classes/$Uuid" -ProtocolVersion 3 | Out-Null
        }
    }
}
