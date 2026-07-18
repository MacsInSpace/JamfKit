function Select-JamfSchoolResult {
    <#
    .SYNOPSIS
        Unwraps a Jamf School response envelope ({code, count, devices:[...]} etc.).
    .DESCRIPTION
        Returns the first named property found on the response (the envelope key
        varies per endpoint — e.g. 'DeviceGroups' on list but 'deviceGroup' on
        detail); falls back to the whole response when none match.
    #>
    [CmdletBinding()]
    param(
        $Response,

        [Parameter(Mandatory)]
        [string[]] $Property
    )

    if ($null -eq $Response) { return $null }
    foreach ($name in $Property) {
        $match = $Response.PSObject.Properties.Match($name)
        if ($match.Count -gt 0) { return $match[0].Value }
    }
    return $Response
}

function Assert-JamfSchoolResponseCode {
    <#
    .SYNOPSIS
        Guards against the API's HTTP-200-but-code-400 responses (e.g. UnlockFailed).
    #>
    [CmdletBinding()]
    param(
        $Response,

        [string] $Context = 'Request'
    )

    if ($null -ne $Response -and $Response -isnot [string]) {
        $codeMatch = $Response.PSObject.Properties.Match('code')
        if ($codeMatch.Count -gt 0 -and [int]$codeMatch[0].Value -ge 400) {
            $message = [string](Select-JamfSchoolResult -Response $Response -Property 'message')
            $reasonMatch = $Response.PSObject.Properties.Match('reason')
            $reason = if ($reasonMatch.Count -gt 0 -and $reasonMatch[0].Value) { " ($($reasonMatch[0].Value))" } else { '' }
            throw "$Context failed: $($codeMatch[0].Value) $message$reason"
        }
    }
    return $Response
}
