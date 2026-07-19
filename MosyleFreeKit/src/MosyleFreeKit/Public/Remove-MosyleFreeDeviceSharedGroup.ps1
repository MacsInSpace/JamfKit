function Remove-MosyleFreeDeviceSharedGroup {
    <#
    .SYNOPSIS
        Removes devices from a Mosyle Shared Device Group by moving them to limbo.
    .DESCRIPTION
        UI label is **Shared Device Groups** (formerly Shared Device Carts). Free UI has no
        separate "remove from group" operation — leaving SHARED uses
        DeviceInfoController / change_to_limbo (optional action=remove_apps).

        To place the device in another Shared Device Group, use Add-MosyleFreeDeviceSharedGroup.
        To assign to a user account instead of limbo, use Set-MosyleFreeDeviceAccount.
    .EXAMPLE
        Remove-MosyleFreeDeviceSharedGroup -Device $udid -WhatIf
    .EXAMPLE
        Remove-MosyleFreeDeviceSharedGroup -Device $udid -RemoveApps -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [string] $SerialNumber,

        [switch] $RemoveApps,

        [switch] $ChangeDeviceModel,

        [int] $DelayMs = 400,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-MosyleFreeSession -Session $Session
        $devices = [System.Collections.Generic.List[string]]::new()
        $serialByDevice = @{}
    }

    process {
        if ($null -ne $Device) {
            foreach ($d in $Device) {
                if (-not $d) { continue }
                [void]$devices.Add($d)
                if ($SerialNumber) { $serialByDevice[$d] = $SerialNumber }
            }
        }
        elseif ($_ -and $_.PSObject.Properties['deviceudid']) {
            [void]$devices.Add([string]$_.deviceudid)
            if ($_.PSObject.Properties['serial_number'] -and $_.serial_number) {
                $serialByDevice[[string]$_.deviceudid] = [string]$_.serial_number
            }
        }
    }

    end {
        if ($devices.Count -eq 0) { throw 'Supply -Device UDIDs.' }
        $osValue = if ($Os) { $Os } else { $resolved.Os }

        foreach ($udid in $devices) {
            $body = @{
                deviceudid = $udid
                action     = $(if ($RemoveApps) { '1' } else { '0' })
            }
            if ($ChangeDeviceModel) {
                $body['changeDeviceModel'] = 'true'
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid (Shared Device Group → limbo)", 'Remove Mosyle Free device from Shared Device Group')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'RemoveSharedGroup'
                    Ok         = $true
                    WhatIf     = $true
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping DeviceInfoController `
                -Operation 'change_to_limbo' -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'RemoveSharedGroup'
                Ok         = $ok
                WhatIf     = $false
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
