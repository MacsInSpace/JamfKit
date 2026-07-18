function Remove-JamfSchoolDevice {
    <#
    .SYNOPSIS
        Moves a Jamf School device to the trash.
    .EXAMPLE
        Remove-JamfSchoolDevice -Udid $udid
    .EXAMPLE
        Get-JamfSchoolDevice -InTrash $false -EnrollType manual | Remove-JamfSchoolDevice -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Udid,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ShouldProcess("Device $Udid", 'Move to trash')) {
            Invoke-JamfSchoolRequest -Session $resolved -Method DELETE -Path "devices/$Udid" | Out-Null
        }
    }
}
