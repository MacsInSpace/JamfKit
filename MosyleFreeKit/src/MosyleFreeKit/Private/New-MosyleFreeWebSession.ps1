function New-MosyleFreeWebSession {
    <#
    .SYNOPSIS
        Builds a WebRequestSession cookie jar from a parsed cookie table.
    .DESCRIPTION
        Free UI sessions may use HttpOnly PHPSESSID and/or the .mosyle.com credentials JWT.
        Cookies are added via Uri overload so CookieContainer sends them to myschool.mosyle.com
        regardless of which domain they were exported from.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private factory; builds an in-memory cookie jar, no external state change.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Cookies,

        [Parameter(Mandatory)]
        [uri] $BaseUri
    )

    $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    $uris = @(
        $BaseUri
        [uri]'https://myschool.mosyle.com/'
        [uri]'https://mosyle.com/'
    ) | Select-Object -Unique

    $added = 0
    foreach ($name in $Cookies.Keys) {
        $value = [string]$Cookies[$name]
        foreach ($u in $uris) {
            try {
                $c = [System.Net.Cookie]::new($name, $value)
                $c.Path = '/'
                $session.Cookies.Add($u, $c)
                $added++
            }
            catch {
                Write-Verbose "Skipped cookie $name for $($u.Host): $($_.Exception.Message)"
            }
        }
    }

    if ($added -eq 0) {
        throw 'No cookies could be loaded into the session jar.'
    }

    $session
}
