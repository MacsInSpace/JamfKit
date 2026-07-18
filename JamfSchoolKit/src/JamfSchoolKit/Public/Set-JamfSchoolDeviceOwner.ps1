function Set-JamfSchoolDeviceOwner {
    <#
    .SYNOPSIS
        Assigns or clears the owner of a Jamf School device.
    .EXAMPLE
        Set-JamfSchoolDeviceOwner -Udid $udid -UserId 1234
    .EXAMPLE
        Set-JamfSchoolDeviceOwner -Udid $udid -Clear
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Assign')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Udid,

        [Parameter(Mandatory, Position = 1, ParameterSetName = 'Assign')]
        [int] $UserId,

        # Remove the current owner (the API's "user 0" convention).
        [Parameter(Mandatory, ParameterSetName = 'Clear')]
        [switch] $Clear,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        $targetUser = if ($Clear) { 0 } else { $UserId }
        $action = if ($Clear) { 'Clear owner' } else { "Assign owner (user $UserId)" }

        if ($PSCmdlet.ShouldProcess("Device $Udid", $action)) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method PUT -Path "devices/$Udid/owner" `
                -Body @{ user = $targetUser }
            Assert-JamfSchoolResponseCode -Response $response -Context $action | Out-Null
        }
    }
}
