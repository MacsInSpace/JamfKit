function Set-JamfSchoolDeviceGroupMember {
    <#
    .SYNOPSIS
        Adds and/or removes devices in a static Jamf School device group.
    .DESCRIPTION
        Uses POST /devices/groups/add and /devices/groups/remove with the documented
        { groupId, udids[] } payload. Static groups only — smart group membership is
        criteria-driven.
    .EXAMPLE
        Set-JamfSchoolDeviceGroupMember -GroupId 12 -Add $udid1, $udid2
    .EXAMPLE
        Set-JamfSchoolDeviceGroupMember -GroupId 12 -Remove (Get-JamfSchoolDevice -AssetTag 'RETIRED').UDID
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [int] $GroupId,

        [string[]] $Add,

        [string[]] $Remove,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    $resolved = Assert-JamfSchoolSession -Session $Session

    if (-not $Add -and -not $Remove) {
        throw 'Supply -Add and/or -Remove.'
    }

    if ($Add) {
        if ($PSCmdlet.ShouldProcess("Device group $GroupId", "Add $(@($Add).Count) device(s)")) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method POST -Path 'devices/groups/add' `
                -Body @{ groupId = $GroupId; udids = @($Add) }
            Assert-JamfSchoolResponseCode -Response $response -Context 'Group add' | Out-Null
            Write-Verbose "Added: $([string](Select-JamfSchoolResult -Response $response -Property 'devicesAdded'))"
        }
    }
    if ($Remove) {
        if ($PSCmdlet.ShouldProcess("Device group $GroupId", "Remove $(@($Remove).Count) device(s)")) {
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method POST -Path 'devices/groups/remove' `
                -Body @{ groupId = $GroupId; udids = @($Remove) }
            Assert-JamfSchoolResponseCode -Response $response -Context 'Group remove' | Out-Null
            Write-Verbose "Removed: $([string](Select-JamfSchoolResult -Response $response -Property 'devicesRemoved'))"
        }
    }
}
