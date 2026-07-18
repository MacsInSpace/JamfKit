function Remove-JamfSchoolUser {
    <#
    .SYNOPSIS
        Deletes a user from Jamf School.
    .EXAMPLE
        Remove-JamfSchoolUser -Id 1234
    .EXAMPLE
        Get-JamfSchoolUser -InTrash $true | Remove-JamfSchoolUser -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [int] $Id,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ShouldProcess("User id $Id", 'Delete Jamf School user')) {
            Invoke-JamfSchoolRequest -Session $resolved -Method DELETE -Path "users/$Id" | Out-Null
        }
    }
}
