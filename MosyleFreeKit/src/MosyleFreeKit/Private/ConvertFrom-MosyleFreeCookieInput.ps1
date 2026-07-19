function ConvertFrom-MosyleFreeCookieInput {
    <#
    .SYNOPSIS
        Parses whatever a user pasted into a cookie table plus an optional school slug.
    .DESCRIPTION
        Getting a Free session should not require knowing which of five paste formats
        the module wants. This accepts all of the shapes a browser can hand you:

          1. JSON       - [{"name":"PHPSESSID","value":"..."}] from a cookie-export add-on
          2. curl       - the whole "Copy as cURL" blob from DevTools > Network
          3. Header     - "Cookie: PHPSESSID=...; credentials=..." (prefix optional)
          4. Table      - tab-separated rows pasted from DevTools > Application > Cookies
          5. Pairs      - "PHPSESSID=..." or "PHPSESSID=...; credentials=..."

        A pasted cURL usually carries the school slug in its form body, so IdSchool is
        recovered from it too and the caller can skip the parameter entirely.
    .OUTPUTS
        pscustomobject with Cookies (ordered name -> value) and IdSchool (or $null).
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Private parser; returns an object, changes no external state.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $InputText
    )

    $cookies = [ordered]@{}
    $idSchool = $null
    $text = $InputText.Trim()

    if (-not $text) {
        throw 'Nothing to parse. Paste a Cookie header, a "Copy as cURL" blob, or PHPSESSID=...'
    }

    # The school slug rides along in a pasted cURL form body.
    $schoolMatch = [regex]::Match($text, 'usertab_current_idschool=([A-Za-z0-9_.-]+)')
    if ($schoolMatch.Success) {
        $idSchool = [uri]::UnescapeDataString($schoolMatch.Groups[1].Value)
    }

    $addPair = {
        param([string] $Name, [string] $Value)
        $n = $Name.Trim().TrimStart('.')
        $v = $Value.Trim().Trim('"', "'")
        if ($n -and $n -notmatch '\s' -and $v) { $cookies[$n] = $v }
    }

    # 1. JSON export from a cookie add-on.
    if ($text.StartsWith('[') -or $text.StartsWith('{')) {
        try {
            $json = $text | ConvertFrom-Json -ErrorAction Stop
            foreach ($entry in @($json)) {
                $nameProp = $entry.PSObject.Properties.Match('name')
                $valueProp = $entry.PSObject.Properties.Match('value')
                if ($nameProp.Count -gt 0 -and $valueProp.Count -gt 0) {
                    & $addPair ([string]$nameProp[0].Value) ([string]$valueProp[0].Value)
                }
            }
            if ($cookies.Count -gt 0) {
                return [pscustomobject]@{ Cookies = $cookies; IdSchool = $idSchool }
            }
        }
        catch {
            Write-Verbose "Input looked like JSON but did not parse: $($_.Exception.Message)"
        }
    }

    # 2. "Copy as cURL" - pull every cookie carrier out of the command line.
    if ($text -match '(?im)^\s*curl\b' -or $text -match '(?i)\s-H\s') {
        $patterns = @(
            "(?i)(?:-b|--cookie)\s+'([^']*)'"
            '(?i)(?:-b|--cookie)\s+"([^"]*)"'
            "(?i)-H\s+'cookie:\s*([^']*)'"
            '(?i)-H\s+"cookie:\s*([^"]*)"'
        )
        foreach ($pattern in $patterns) {
            foreach ($m in [regex]::Matches($text, $pattern)) {
                foreach ($pair in $m.Groups[1].Value -split ';') {
                    if ($pair -match '^\s*([^=]+)=(.*)$') {
                        & $addPair $Matches[1] $Matches[2]
                    }
                }
            }
        }
        if ($cookies.Count -gt 0) {
            return [pscustomobject]@{ Cookies = $cookies; IdSchool = $idSchool }
        }
    }

    # 3/5. Cookie header or bare pairs, possibly spread over several lines.
    foreach ($line in $text -split '\r?\n') {
        $candidate = $line.Trim()
        if (-not $candidate) { continue }
        $candidate = $candidate -replace '(?i)^\s*(set-)?cookie:\s*', ''

        # 4. DevTools table row: name <tab> value <tab> domain ...
        if ($candidate -match "^([^\s=]+)[`t]+(\S+)") {
            & $addPair $Matches[1] $Matches[2]
            continue
        }

        foreach ($pair in $candidate -split ';') {
            if ($pair -match '^\s*([^=]+)=(.*)$') {
                & $addPair $Matches[1] $Matches[2]
            }
        }
    }

    if ($cookies.Count -eq 0) {
        throw 'No cookies found in that paste. Expected something like "PHPSESSID=..." or a "Copy as cURL" blob from DevTools.'
    }

    [pscustomobject]@{ Cookies = $cookies; IdSchool = $idSchool }
}
