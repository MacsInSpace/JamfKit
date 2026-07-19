function Remove-MosyleFreeDeviceTag {
    <#
    .SYNOPSIS
        Removes a tag from devices via the Mosyle Free UI (devices_bulk_remove_tag).
    .DESCRIPTION
        Matches the typed remove-tag dialog (tag_name + devices). Comma-separated
        tag_name is accepted by the UI when multiple checkboxes are selected.
    .EXAMPLE
        Remove-MosyleFreeDeviceTag -Device $udid -Tag 'FreeKit-stale-probe' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [Parameter(Mandatory)]
        [Alias('TagName')]
        [string] $Tag,

        [string] $SerialNumber,

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
                devices    = $udid
                deviceudid = $udid
                tag_name   = $Tag
                turn       = '0'
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid -tag $Tag", 'Remove Mosyle Free device tag')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'RemoveTag'
                    Ok         = $true
                    WhatIf     = $true
                    Tag        = $Tag
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping BulkOperationsController `
                -Operation 'devices_bulk_remove_tag' -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'RemoveTag'
                Ok         = $ok
                WhatIf     = $false
                Tag        = $Tag
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
