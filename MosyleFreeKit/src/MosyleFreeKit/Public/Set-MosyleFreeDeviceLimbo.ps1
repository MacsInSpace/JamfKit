function Set-MosyleFreeDeviceLimbo {
    <#
    .SYNOPSIS
        Moves devices to Mosyle limbo (unassigned) via the Free UI.
    .DESCRIPTION
        Matches MDMBulkOperations.turnIntoLimbo / MDMDevice modality change:
        DeviceInfoController / change_to_limbo (default) with optional action=remove_apps.

        Also used to leave a Shared Device Group (SHARED → limbo). Prefer
        Remove-MosyleFreeDeviceSharedGroup for that flow.
        Use -Operation change_to_11enroll when the UI modality dialog uses that op.
    .EXAMPLE
        Set-MosyleFreeDeviceLimbo -Device $udid -RemoveApps -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [string] $SerialNumber,

        [switch] $RemoveApps,

        [switch] $ChangeDeviceModel,

        [ValidateSet('change_to_limbo', 'change_to_11enroll')]
        [string] $Operation = 'change_to_limbo',

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
            }
            if ($RemoveApps) {
                $body['action'] = '1'
            } else {
                $body['action'] = '0'
            }
            if ($ChangeDeviceModel) {
                $body['changeDeviceModel'] = 'true'
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid → limbo ($Operation)", 'Move Mosyle Free device to limbo')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'SetLimbo'
                    Ok         = $true
                    WhatIf     = $true
                    Operation  = $Operation
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping DeviceInfoController `
                -Operation $Operation -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'SetLimbo'
                Ok         = $ok
                WhatIf     = $false
                Operation  = $Operation
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
