function Get-MosyleFreeDeviceCommand {
    <#
    .SYNOPSIS
        Lists pending/failed commands for a device from the Free device Commands tab.
    .DESCRIPTION
        Posts to screens/scules/mdm/deviceinfo/device_commands.php — the same HTML the
        UI Commands tab uses. Prefer this over the global pending list when verifying
        that a Free UI command actually queued (soft status:OK is not enough).

        Returns no objects when the device has no pending or failed commands.
    .PARAMETER Device
        Device UDID.
    .PARAMETER SerialNumber
        Optional serial (helps Mosyle render the tab; taken from pipeline devices when present).
    .PARAMETER Status
        Filter to Pending or Failed after parse.
    .EXAMPLE
        Get-MosyleFreeDeviceCommand -Device $udid -SerialNumber ABCD1234EFGH
    .EXAMPLE
        Get-MosyleFreeDevice -SerialNumber ABCD1234EFGH | Get-MosyleFreeDeviceCommand
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('serial_number')]
        [string] $SerialNumber,

        [ValidateSet('Pending', 'Failed')]
        [string] $Status,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-MosyleFreeSession -Session $Session
        $osValue = if ($Os) { $Os } else { $resolved.Os }
        $items = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($udid in $Device) {
            if ([string]::IsNullOrWhiteSpace($udid)) { continue }

            $serial = $SerialNumber
            if (-not $serial -and $_ -and $_.PSObject.Properties['serial_number']) {
                $serial = [string]$_.serial_number
            }

            $body = @{
                deviceudid    = $udid
                action        = 'COMMANDS'
                serial_number = if ($serial) { $serial } else { '' }
                os            = $osValue
            }

            $result = Invoke-MosyleFreeUi -Path 'screens/scules/mdm/deviceinfo/device_commands.php' `
                -Body $body -Session $resolved -Confirm:$false

            if ($result.StatusCode -lt 200 -or $result.StatusCode -ge 300) {
                throw "Device commands failed for ${udid}: HTTP $($result.StatusCode)"
            }

            $html = if ($null -ne $result.RawContent) { [string]$result.RawContent } else { '' }
            $rows = ConvertFrom-MosyleFreeDeviceCommandsHtml -Html $html -Device $udid -SerialNumber $serial
            foreach ($row in $rows) {
                if ($Status -and $row.Status -ne $Status) { continue }
                [void]$items.Add($row)
            }
        }
    }

    end {
        @($items)
    }
}
