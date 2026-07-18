function Disconnect-JamfSchool {
    <#
    .SYNOPSIS
        Clears the module's default Jamf School session.
    .DESCRIPTION
        Jamf School API keys have no server-side session to invalidate (keys never
        expire); this drops the cached credential from the PowerShell session.
    .EXAMPLE
        Disconnect-JamfSchool
    #>
    [CmdletBinding()]
    param(
        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    $target = if ($null -ne $Session) { $Session } else { $script:DefaultJamfSchoolSession }
    if ($null -eq $target) {
        Write-Verbose 'No active Jamf School session to disconnect.'
        return
    }

    $target.Credential = $null
    if ($script:DefaultJamfSchoolSession -eq $target) {
        $script:DefaultJamfSchoolSession = $null
    }
}
