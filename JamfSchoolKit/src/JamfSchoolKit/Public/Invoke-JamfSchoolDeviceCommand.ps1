function Invoke-JamfSchoolDeviceCommand {
    <#
    .SYNOPSIS
        Sends a management command to a Jamf School device.
    .DESCRIPTION
        Supported commands and their options:
          Restart              (-ClearPasscode)
          Wipe                 (-ClearActivationLock)
          Refresh              (-ClearErrors)  — refreshes device information
          Restore
          Unenroll
          ClearActivationLock
        The API sometimes reports failure inside an HTTP 200 body (e.g. UnlockFailed);
        this cmdlet surfaces those as errors instead of silent success.
    .EXAMPLE
        Invoke-JamfSchoolDeviceCommand -Udid $udid -Command Restart
    .EXAMPLE
        Get-JamfSchoolDevice -Groups 12 | Invoke-JamfSchoolDeviceCommand -Command Refresh -Confirm:$false
    .EXAMPLE
        Invoke-JamfSchoolDeviceCommand -Udid $udid -Command Wipe -ClearActivationLock -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Udid,

        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('Restart', 'Wipe', 'Refresh', 'Restore', 'Unenroll', 'ClearActivationLock')]
        [string] $Command,

        # Wipe only: also clear the Activation Lock so the device can be re-setup.
        [switch] $ClearActivationLock,

        # Restart only: clear the passcode before restarting.
        [switch] $ClearPasscode,

        # Refresh only: clear failed/pending command errors first.
        [switch] $ClearErrors,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        $path = switch ($Command) {
            'ClearActivationLock' { "devices/$Udid/activationlock/clear" }
            default { "devices/$Udid/$($Command.ToLowerInvariant())" }
        }

        # The API expects these flags as string booleans.
        $body = $null
        switch ($Command) {
            'Wipe' { if ($ClearActivationLock) { $body = @{ clearActivationLock = 'true' } } }
            'Restart' { if ($ClearPasscode) { $body = @{ clearPasscode = 'true' } } }
            'Refresh' { if ($ClearErrors) { $body = @{ clearErrors = $true } } }
        }

        if ($PSCmdlet.ShouldProcess("Device $Udid", $Command)) {
            $params = @{ Session = $resolved; Method = 'POST'; Path = $path }
            if ($null -ne $body) { $params['Body'] = $body }
            $response = Invoke-JamfSchoolRequest @params
            Assert-JamfSchoolResponseCode -Response $response -Context "$Command on $Udid" | Out-Null
            Write-Verbose "$Command on ${Udid}: $([string](Select-JamfSchoolResult -Response $response -Property 'message'))"
        }
    }
}
