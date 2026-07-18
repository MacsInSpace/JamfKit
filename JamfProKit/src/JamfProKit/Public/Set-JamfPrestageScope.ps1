function Set-JamfPrestageScope {
    <#
    .SYNOPSIS
        Adds, removes or replaces serial numbers in a PreStage enrollment scope —
        The MUT's PreStage mode.
    .DESCRIPTION
        Updates computer or mobile device PreStage scope via the Jamf Pro API
        (/api/v2/computer-prestages and /api/v2/mobile-device-prestages).

        PreStage scope uses optimistic concurrency: every write must carry the scope's
        current versionLock. This cmdlet fetches a fresh lock before each write and,
        if another process changed the scope mid-flight (version conflict), refetches
        and retries automatically up to -MaxConflictRetries times.

        Identifiers are always serial numbers (the API accepts nothing else).
    .EXAMPLE
        Set-JamfPrestageScope -PrestageId 3 -Add C02AAA111, C02BBB222
    .EXAMPLE
        Set-JamfPrestageScope -PrestageId 5 -Type MobileDevice -Remove (Import-Csv scope.csv).'Serial Numbers or Usernames'
    .EXAMPLE
        Set-JamfPrestageScope -PrestageId 3 -Replace (Get-Content serials.txt) -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Delta')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'MaxConflictRetries',
        Justification = 'Used inside the nested Invoke-ScopeWrite helper; the analyzer cannot see through the closure.')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $PrestageId,

        [ValidateSet('Computer', 'MobileDevice')]
        [string] $Type = 'Computer',

        [Parameter(ParameterSetName = 'Delta')]
        [string[]] $Add,

        [Parameter(ParameterSetName = 'Delta')]
        [string[]] $Remove,

        [Parameter(Mandatory, ParameterSetName = 'Replace')]
        [AllowEmptyCollection()]
        [string[]] $Replace,

        [ValidateRange(0, 10)]
        [int] $MaxConflictRetries = 3,

        [PSTypeName('JamfProKit.Session')]
        [object] $Session
    )

    $resolved = Assert-JamfSession -Session $Session

    if ($PSCmdlet.ParameterSetName -eq 'Delta' -and -not $Add -and -not $Remove) {
        throw 'Supply -Add and/or -Remove, or use -Replace.'
    }

    $basePath = if ($Type -eq 'Computer') { 'api/v2/computer-prestages' } else { 'api/v2/mobile-device-prestages' }
    $scopePath = "$basePath/$PrestageId/scope"

    function Invoke-ScopeWrite {
        param(
            [string] $Method,
            [string] $Path,
            [string[]] $Serials,
            [string] $OperationLabel
        )

        for ($attempt = 0; $attempt -le $MaxConflictRetries; $attempt++) {
            $scope = Invoke-JamfRequest -Session $resolved -Method GET -Path $scopePath
            if ($null -eq $scope -or $scope.PSObject.Properties.Match('versionLock').Count -eq 0) {
                throw "Unexpected response reading the scope of $Type PreStage $PrestageId (no versionLock)."
            }
            try {
                return Invoke-JamfRequest -Session $resolved -Method $Method -Path $Path -Body @{
                    serialNumbers = @($Serials)
                    versionLock   = $scope.versionLock
                }
            }
            catch {
                $isConflict = $_.Exception.Message -match 'HTTP 409|VERSION.?LOCK|OPTIMISTIC'
                if ($isConflict -and $attempt -lt $MaxConflictRetries) {
                    Write-Verbose "$OperationLabel hit a versionLock conflict; refetching and retrying ($($attempt + 1)/$MaxConflictRetries)."
                    continue
                }
                throw
            }
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'Replace') {
        if ($PSCmdlet.ShouldProcess("$Type PreStage id $PrestageId", "Replace scope with $(@($Replace).Count) serial(s)")) {
            Invoke-ScopeWrite -Method PUT -Path $scopePath -Serials $Replace -OperationLabel 'Replace'
        }
        return
    }

    if ($Add) {
        if ($PSCmdlet.ShouldProcess("$Type PreStage id $PrestageId", "Add $(@($Add).Count) serial(s) to scope")) {
            Invoke-ScopeWrite -Method POST -Path $scopePath -Serials $Add -OperationLabel 'Add'
        }
    }
    if ($Remove) {
        if ($PSCmdlet.ShouldProcess("$Type PreStage id $PrestageId", "Remove $(@($Remove).Count) serial(s) from scope")) {
            Invoke-ScopeWrite -Method POST -Path "$scopePath/delete-multiple" -Serials $Remove -OperationLabel 'Remove'
        }
    }
}
