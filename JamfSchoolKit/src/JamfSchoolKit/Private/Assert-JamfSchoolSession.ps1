function Assert-JamfSchoolSession {
    <#
    .SYNOPSIS
        Resolves the session a cmdlet should use, or throws a friendly error.
    #>
    [CmdletBinding()]
    param(
        [object] $Session
    )

    if ($null -ne $Session) {
        if ($Session.PSObject.TypeNames -notcontains 'JamfSchoolKit.Session') {
            throw 'The supplied -Session object is not a JamfSchoolKit session. Use Connect-JamfSchool to create one.'
        }
        return $Session
    }
    if ($null -ne $script:DefaultJamfSchoolSession) {
        return $script:DefaultJamfSchoolSession
    }
    throw 'Not connected to a Jamf School server. Run Connect-JamfSchool first.'
}
