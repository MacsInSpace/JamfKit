function Set-MosyleFreeDeviceAccount {
    <#
    .SYNOPSIS
        Assigns a device to a Mosyle account (change_device_account).
    .DESCRIPTION
        Free UI path used when moving a device between accounts / out of limbo into an
        account. Posts DeviceInfoController / change_device_account with newAccount.

        This is account assignment, not the paid API "assign_device" user ownership op.
        End-user 1:1 assignment UI (deviceassign) was not exposed on Free for capture.
    .PARAMETER AccountId
        Mosyle idaccount value (newAccount in the UI payload).
    .PARAMETER RemoveApps
        When moving a non-limbo device, UI may pass remove_apps (0/1).
    .EXAMPLE
        Set-MosyleFreeDeviceAccount -Device $udid -AccountId '12345' -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [Parameter(Mandatory)]
        [Alias('newAccount', 'IdAccount')]
        [string] $AccountId,

        [string] $SerialNumber,

        [ValidateSet(0, 1)]
        [int] $RemoveApps,

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
                newAccount = $AccountId
            }
            if ($PSBoundParameters.ContainsKey('RemoveApps')) {
                $body['remove_apps'] = [string]$RemoveApps
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            if (-not $PSCmdlet.ShouldProcess("$udid → account $AccountId", 'Set Mosyle Free device account')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = 'SetAccount'
                    Ok         = $true
                    WhatIf     = $true
                    AccountId  = $AccountId
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping DeviceInfoController `
                -Operation 'change_device_account' -Body $body -Os $osValue `
                -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Device     = $udid
                Command    = 'SetAccount'
                Ok         = $ok
                WhatIf     = $false
                AccountId  = $AccountId
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }

            if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
        }
    }
}
