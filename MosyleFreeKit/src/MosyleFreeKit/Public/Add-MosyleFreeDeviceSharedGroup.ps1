function Add-MosyleFreeDeviceSharedGroup {
    <#
    .SYNOPSIS
        Adds devices to a Mosyle Shared Device Group (change_to_sharedenroll).
    .DESCRIPTION
        UI label is **Shared Device Groups** (formerly Shared Device Carts / shared tablet carts).
        Free bus still posts DeviceInfoController / change_to_sharedenroll with form field
        idcart (legacy MosyleSelector JSON array, e.g. [2]). Inventory then shows
        enrollment_type=SHARED and idsharedgroup=<GroupId>.

        To leave a group, use Remove-MosyleFreeDeviceSharedGroup (limbo) or
        Set-MosyleFreeDeviceAccount.
    .PARAMETER GroupId
        Shared Device Group id. Sent as idcart=[N]; matches device idsharedgroup when assigned.
    .PARAMETER Name
        Resolve GroupId via Get-MosyleFreeSharedDeviceGroup -Name (e.g. 'Student Devices').
    .EXAMPLE
        Add-MosyleFreeDeviceSharedGroup -Device $udid -GroupId '2' -WhatIf
    .EXAMPLE
        Add-MosyleFreeDeviceSharedGroup -Device $udid -Name 'Student Devices' -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [Alias('CartId', 'IdCart', 'idsharedgroup', 'idshareddevicegroup', 'SharedGroupId')]
        [string] $GroupId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [Alias('CartName', 'GroupName')]
        [string] $Name,

        [string] $SerialNumber,

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

        $resolvedGroupId = $GroupId
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $hit = @(Get-MosyleFreeSharedDeviceGroup -Name $Name -Session $resolved -Os $osValue)
            if ($hit.Count -eq 0) { throw "No Shared Device Group named '$Name'." }
            if ($hit.Count -gt 1) { throw "Multiple groups match '$Name'. Use -GroupId." }
            $resolvedGroupId = $hit[0].GroupId
        }

        foreach ($udid in $devices) {
            # MosyleSelector posts idcart as a JSON array; bare "2" soft-OKs without assigning.
            $idcart = if ($resolvedGroupId.Trim().StartsWith('[')) {
                $resolvedGroupId.Trim()
            } else {
                '[{0}]' -f ($resolvedGroupId.Trim() -replace '^"|"$', '')
            }

            $body = @{
                deviceudid = $udid
                idcart     = $idcart
            }
            if ($ChangeDeviceModel) {
                $body['changeDeviceModel'] = 'true'
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid → Shared Device Group $resolvedGroupId", 'Add Mosyle Free device to Shared Device Group')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'AddSharedGroup'
                    Ok         = $true
                    WhatIf     = $true
                    GroupId    = $resolvedGroupId
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping DeviceInfoController `
                -Operation 'change_to_sharedenroll' -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'AddSharedGroup'
                Ok         = $ok
                WhatIf     = $false
                GroupId    = $resolvedGroupId
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
