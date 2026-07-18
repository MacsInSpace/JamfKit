function Get-JamfSchoolSession {
    <#
    .SYNOPSIS
        Returns the current default Jamf School session, if connected.
    .EXAMPLE
        Get-JamfSchoolSession
    #>
    [CmdletBinding()]
    param()

    $script:DefaultJamfSchoolSession
}
