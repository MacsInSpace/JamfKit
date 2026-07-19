function Test-MosyleFreeLoginPage {
    <#
    .SYNOPSIS
        Returns $true if a response body looks like the Mosyle login / session-expired page.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Content,

        [string] $RawContent
    )

    $text = if ($PSBoundParameters.ContainsKey('RawContent') -and $RawContent) {
        $RawContent
    }
    elseif ($Content -is [string]) {
        $Content
    }
    else {
        return $false
    }

    if ($text -match 'Enter your email') { return $true }
    if ($text -match 'window\.location\.href\s*=\s*["'']\.\/["'']') { return $true }
    return $false
}
