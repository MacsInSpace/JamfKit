function Invoke-MosyleFreeDeviceCommand {
    <#
    .SYNOPSIS
        Sends a device command via the Mosyle Free UI (Controller/mapping.php fan-out).
    .DESCRIPTION
        Free has no /bulkops API. This cmdlet posts one mapping.php call per UDID
        (serial by default). Supported commands:

          Restart, Shutdown, Lock, Wipe, Unassign,
          ClearCommands, ClearPendingCommands, ClearFailedCommands,
          EnableActivationLock, DisableActivationLock,
          SendPush, UpdateInfo

        Lost Mode has its own cmdlet: Invoke-MosyleFreeLostMode.
        Tags: Set-MosyleFreeDeviceTag / Remove-MosyleFreeDeviceTag.
        Account move: Set-MosyleFreeDeviceAccount.

        Soft status:OK is not proof a command queued. Restart in particular has been
        observed to soft-OK with no pending row. Use -Verify to check the device
        Commands tab after send (sets Queued on the result). -Verify settles briefly
        and retries so late-appearing rows (e.g. Restart OS) are not missed.
        Wipe requires -Confirm.

        Supply -AdminCredential on Connect-MosyleFree (or here) when Mosyle requires
        the security-confirm password.
    .EXAMPLE
        Invoke-MosyleFreeDeviceCommand -Command Restart -Device $udid -WhatIf
    .EXAMPLE
        Get-MosyleFreeDevice -SerialNumber ABCD1234EFGH |
            Invoke-MosyleFreeDeviceCommand -Command Lock -LockMessage 'Return to IT' -Verify
    .EXAMPLE
        Invoke-MosyleFreeDeviceCommand -Command Wipe -Device $udid -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateSet(
            'Restart', 'Shutdown', 'Lock', 'Wipe', 'Unassign',
            'ClearCommands', 'ClearPendingCommands', 'ClearFailedCommands',
            'EnableActivationLock', 'DisableActivationLock',
            'SendPush', 'UpdateInfo'
        )]
        [string] $Command,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UDID', 'deviceudid')]
        [string[]] $Device,

        [string] $SerialNumber,

        [int] $Pincode,
        [string] $PhoneNumber,
        [string] $LockMessage,
        [Alias('LostMessage')]
        [string] $Message,

        [ValidateSet('pending', 'failed', 'error', '')]
        [string] $CommandStatus = 'pending',

        [int] $DelayMs = 400,

        [switch] $Verify,

        [int] $VerifySettleMs = 500,

        [ValidateRange(1, 10)]
        [int] $VerifyAttempts = 3,

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
            Restart               = @{ Mapping = 'BulkOperationsController'; Operation = 'bulk_restart' }
            Shutdown              = @{ Mapping = 'BulkOperationsController'; Operation = 'bulk_shutdown' }
            Lock                  = @{ Mapping = 'BulkOperationsController'; Operation = 'lock_device' }
            Wipe                  = @{ Mapping = 'BulkOperationsController'; Operation = 'wipe_device' }
            Unassign              = @{ Mapping = 'BulkOperationsController'; Operation = 'change_to_limbo' }
            ClearCommands         = @{ Mapping = 'CommandController'; Operation = 'device_clear_commands'; Status = 'pending' }
            ClearPendingCommands  = @{ Mapping = 'CommandController'; Operation = 'device_clear_commands'; Status = 'pending' }
            ClearFailedCommands   = @{ Mapping = 'CommandController'; Operation = 'device_clear_commands'; Status = 'failed' }
            EnableActivationLock  = @{ Mapping = 'BulkOperationsController'; Operation = 'bulk_enable_activation_lock' }
            DisableActivationLock = @{ Mapping = 'BulkOperationsController'; Operation = 'disable_activationlock' }
            SendPush              = @{ Mapping = 'BulkOperationsController'; Operation = 'bulk_send_push' }
            UpdateInfo            = @{ Mapping = 'BulkOperationsController'; Operation = 'update_info' }
        }

        # Labels observed on device_commands.php Pending Command rows
        $verifyLabels = @{
            Restart    = @('Restart OS', 'Restart device', 'Restart')
            Shutdown   = @('Shutdown Device', 'Shutdown')
            Lock       = @('Turn Off the Screen', 'Lock')
            Wipe       = @('Erase Device', 'Wipe Device', 'Erase')
            UpdateInfo = @('Update Info', 'DeviceInformation')
            SendPush   = @('Send Push', 'Push')
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
        if ($Command -eq 'EnableActivationLock') {
            $msg = if ($Message) { $Message } elseif ($LockMessage) { $LockMessage } else { $null }
            if (-not $msg) {
                throw '-Message (or -LockMessage / -LostMessage) is required for EnableActivationLock.'
            }
        }

        $cred = if ($AdminCredential) { $AdminCredential } else { $resolved.AdminCredential }
        $password = if ($cred) { $cred.GetNetworkCredential().Password } else { $null }
        $osValue = if ($Os) { $Os } else { $resolved.Os }
        $meta = $operationMap[$Command]

        foreach ($udid in $devices) {
            if ([string]::IsNullOrWhiteSpace($udid)) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = $Command
                    Ok         = $false
                    WhatIf     = $false
                    Queued     = $null
                    Error      = 'Empty device UDID refused (soft-OK trap on Free UI).'
                }
                continue
            }

            $body = @{
                deviceudid = $udid
            }

            switch ($Command) {
                'Restart' {
                    $body['devices'] = $udid
                    if ($password) { $body['password'] = $password }
                }
                'Shutdown' {
                    $body['devices'] = $udid
                    if ($password) { $body['password'] = $password }
                }
                'SendPush' {
                    # selectForPush uses deviceudid (already set)
                }
                'UpdateInfo' {
                    # selectForUpdateInfo uses deviceudid (already set)
                }
                'Lock' {
                    if ($PSBoundParameters.ContainsKey('Pincode')) { $body['pin_code'] = [string]$Pincode }
                    if ($LockMessage) { $body['LockMessage'] = $LockMessage }
                    if ($PhoneNumber) { $body['LockPhone'] = $PhoneNumber }
                    if ($password) { $body['password'] = $password }
                }
                'Wipe' {
                    if ($PSBoundParameters.ContainsKey('Pincode')) { $body['pin_code'] = [string]$Pincode }
                    if ($password) { $body['password'] = $password }
                }
                'Unassign' {
                    # change_to_limbo
                }
                'EnableActivationLock' {
                    $body['lost_message'] = $(if ($Message) { $Message } else { $LockMessage })
                }
                'DisableActivationLock' {
                    # no extra fields
                }
                { $_ -like 'Clear*' } {
                    $status = if ($CommandStatus) { $CommandStatus } elseif ($meta.Status) { $meta.Status } else { 'pending' }
                    $body['command_status'] = $status
                }
            }

            if ($serialByDevice.ContainsKey($udid)) {
                $body['serial_number'] = $serialByDevice[$udid]
            }

            $target = "$Command → $udid"
            if (-not $PSCmdlet.ShouldProcess($target, 'Mosyle Free UI device command')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = $Command
                    Ok         = $true
                    WhatIf     = $true
                    Queued     = $null
                    StatusCode = $null
                    Content    = $null
                }
                continue
            }

            try {
                $result = Invoke-MosyleFreeUi -Mapping $meta.Mapping -Operation $meta.Operation `
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

                $queued = $null
                if ($Verify -and $ok) {
                    $serial = if ($serialByDevice.ContainsKey($udid)) { $serialByDevice[$udid] } else { $null }

                    for ($attempt = 1; $attempt -le $VerifyAttempts; $attempt++) {
                        if ($VerifySettleMs -gt 0) {
                            Start-Sleep -Milliseconds $VerifySettleMs
                        }

                        $pending = @(Get-MosyleFreeDeviceCommand -Device $udid -SerialNumber $serial `
                                -Status Pending -Os $osValue -Session $resolved)

                        if ($Command -like 'Clear*') {
                            # Cleared successfully when no pending remain (for pending clear)
                            $queued = $false
                            if ($Command -eq 'ClearFailedCommands') {
                                $failed = @(Get-MosyleFreeDeviceCommand -Device $udid -SerialNumber $serial `
                                        -Status Failed -Os $osValue -Session $resolved)
                                $queued = $failed.Count -gt 0
                            }
                            else {
                                $queued = $pending.Count -gt 0
                            }
                            # For clear ops Queued=$true means commands still present (clear incomplete)
                            if (-not $queued) { break }
                        }
                        elseif ($verifyLabels.ContainsKey($Command)) {
                            $labels = $verifyLabels[$Command]
                            $queued = $false
                            foreach ($row in $pending) {
                                foreach ($label in $labels) {
                                    if ($row.Label -like "*$label*" -or $row.Detail -like "*$label*") {
                                        $queued = $true
                                        break
                                    }
                                }
                                if ($queued) { break }
                            }
                            if ($queued) { break }
                        }
                        else {
                            break
                        }
                    }
                }

                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Device     = $udid
                    Command    = $Command
                    Ok         = $ok
                    WhatIf     = $false
                    Queued     = $queued
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
                    Command    = $Command
                    Ok         = $false
                    WhatIf     = $false
                    Queued     = $null
                    Error      = $_.Exception.Message
                }
            }

            if ($DelayMs -gt 0) {
                Start-Sleep -Milliseconds $DelayMs
            }
        }
    }
}
