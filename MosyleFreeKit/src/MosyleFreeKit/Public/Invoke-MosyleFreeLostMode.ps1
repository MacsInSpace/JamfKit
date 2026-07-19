function Invoke-MosyleFreeLostMode {
    <#
    .SYNOPSIS
        Controls Lost Mode on Mosyle Free devices via the UI command bus.
    .DESCRIPTION
        Maps to BulkOperationsController operations discovered on Free (iOS-named ops):
          Enable           → ios_enable_lostmode  (-Message required; -PhoneNumber / -Footnote optional)
          Disable          → ios_disable_lostmode
          PlaySound        → ios_lostmode_sound
          RequestLocation  → ios_request_location

        Validated on supervised ASM iPad. Same operation names are posted for mac/tvOS
        sessions when -Os is set — delivery is best-effort / untested; expect soft OK
        without queue if the platform does not support Lost Mode.
    .EXAMPLE
        Invoke-MosyleFreeLostMode -Action Enable -Device $udid -Message 'Call the office' -PhoneNumber '03 1234 5678'
    .EXAMPLE
        Invoke-MosyleFreeLostMode -Action RequestLocation -Device $udid -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet('Enable', 'Disable', 'PlaySound', 'RequestLocation')]
        [string] $Action,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [string] $SerialNumber,

        [string] $Message,

        [string] $PhoneNumber,

        [string] $Footnote,

        [int] $DelayMs = 400,

        [pscredential] $AdminCredential,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-MosyleFreeSession -Session $Session
        $devices = [System.Collections.Generic.List[string]]::new()
        $serialByDevice = @{}
        $operationMap = @{
            Enable          = 'ios_enable_lostmode'
            Disable         = 'ios_disable_lostmode'
            PlaySound       = 'ios_lostmode_sound'
            RequestLocation = 'ios_request_location'
        }
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
        if ($devices.Count -eq 0) {
            throw 'Supply -Device (UDIDs) or pipe objects with deviceudid / UDID.'
        }
        if ($Action -eq 'Enable' -and -not $Message) {
            throw '-Message is required when enabling Lost Mode.'
        }

        $cred = if ($AdminCredential) { $AdminCredential } else { $resolved.AdminCredential }
        $password = if ($cred) { $cred.GetNetworkCredential().Password } else { $null }
        $osValue = if ($Os) { $Os } else { $resolved.Os }
        $operation = $operationMap[$Action]

        foreach ($udid in $devices) {
            $body = @{
                deviceudid = $udid
            }
            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }
            if ($Action -eq 'Enable') {
                $body['message'] = $Message
                if ($PhoneNumber) { $body['phone'] = $PhoneNumber }
                if ($Footnote) { $body['footnote'] = $Footnote }
            }
            if ($password -and $Action -in @('Disable', 'Enable', 'PlaySound', 'RequestLocation')) {
                # UI prompts password for multi-device / supervised flows; harmless if unused
                $body['password'] = $password
            }

            $target = "Lost Mode $Action → $udid"
            if (-not $PSCmdlet.ShouldProcess($target, 'Mosyle Free UI Lost Mode')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = "LostMode:$Action"
                    Ok         = $true
                    WhatIf     = $true
                }
                continue
            }

            try {
                $result = Invoke-MosyleFreeUi -Mapping BulkOperationsController -Operation $operation `
                    -Body $body -Os $osValue -Session $resolved -Confirm:$false

                $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
                $statusText = $null
                if ($result.Content -is [pscustomobject] -and $result.Content.PSObject.Properties['status']) {
                    $statusText = [string]$result.Content.status
                    if ($statusText -and $statusText -ne 'OK') { $ok = $false }
                }
                if ($result.RawContent -match '(?i)not valid|not available|no permission|forbidden') {
                    $ok = $false
                }

                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = "LostMode:$Action"
                    Ok         = $ok
                    WhatIf     = $false
                    StatusCode = $result.StatusCode
                    Status     = $statusText
                    Content    = $result.Content
                    RawContent = $result.RawContent
                }
            }
            catch {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = "LostMode:$Action"
                    Ok         = $false
                    WhatIf     = $false
                    Error      = $_.Exception.Message
                }
            }

            if ($DelayMs -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }
        }
    }
}
