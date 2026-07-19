function Set-MosyleFreeDeviceName {
    <#
    .SYNOPSIS
        Renames devices via the Mosyle Free UI (bullk_change_devicesname — Mosyle's spelling).
    .DESCRIPTION
        UI More menu labels this "Rename Devices Premium"; the mapping.php operation still
        exists on Free. -Action is passed through as the UI dialog's action field (default 1).
    .EXAMPLE
        Set-MosyleFreeDeviceName -Device $udid -Name 'Library iPad 7' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [Parameter(Mandatory)]
        [Alias('NewName', 'device_name')]
        [string] $Name,

        [string] $SerialNumber,

        [string] $Action = '1',

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
                newname    = $Name
                action     = $Action
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid → $Name", 'Rename Mosyle Free device')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'Rename'
                    Ok         = $true
                    WhatIf     = $true
                    Name       = $Name
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping BulkOperationsController `
                -Operation 'bullk_change_devicesname' -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'Rename'
                Ok         = $ok
                WhatIf     = $false
                Name       = $Name
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
