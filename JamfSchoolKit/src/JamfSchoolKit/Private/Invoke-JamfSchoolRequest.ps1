function Invoke-JamfSchoolRequest {
    <#
    .SYNOPSIS
        Hardened request pipeline used by every cmdlet in the module.
    .DESCRIPTION
        Responsibilities:
          - Sends HTTP Basic auth (Network ID + API key) on every request — the Jamf
            School API has no token exchange.
          - ALWAYS sends X-Server-Protocol-Version. The API silently defaults to
            protocol v1 when the header is missing while the docs describe v3+
            responses — a classic footgun this engine removes.
          - Serializes hashtable/PSCustomObject bodies to JSON.
          - Retries 429 and transient 5xx with backoff, honoring Retry-After.
          - Throws a normalized error, surfacing the API's {code, message} body.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session,

        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string] $Method = 'GET',

        # Relative path under /api, e.g. 'devices' or 'devices/ABC123/restart'.
        [Parameter(Mandatory)]
        [string] $Path,

        [hashtable] $Query,

        [object] $Body,

        # Overrides the session's default X-Server-Protocol-Version for this call.
        [int] $ProtocolVersion = 0,

        [int] $TimeoutSec = 300,

        [int] $MaxRetries = 4
    )

    $uriBuilder = [System.Text.StringBuilder]::new()
    [void]$uriBuilder.Append($Session.BaseUri).Append('/api/').Append($Path.Trim('/'))
    if ($null -ne $Query -and $Query.Count -gt 0) {
        $pairs = foreach ($key in $Query.Keys) {
            foreach ($value in @($Query[$key])) {
                '{0}={1}' -f [uri]::EscapeDataString([string]$key), [uri]::EscapeDataString([string]$value)
            }
        }
        [void]$uriBuilder.Append('?').Append($pairs -join '&')
    }
    $uri = [uri]$uriBuilder.ToString()

    $requestBody = $Body
    $contentType = $null
    if ($null -ne $Body -and $Body -isnot [string]) {
        $requestBody = ConvertTo-Json -InputObject $Body -Depth 32 -Compress
        $contentType = 'application/json'
    }
    elseif ($Body -is [string]) {
        $contentType = 'application/json'
    }

    $effectiveProtocol = if ($ProtocolVersion -gt 0) { $ProtocolVersion } else { $Session.ProtocolVersion }
    $headers = @{
        'X-Server-Protocol-Version' = [string]$effectiveProtocol
        Accept                      = 'application/json'
    }

    $attempt = 0
    while ($true) {
        Write-Verbose "$Method $uri (attempt $($attempt + 1))"
        $params = @{
            Uri        = $uri
            Method     = $Method
            Headers    = $headers
            Credential = $Session.Credential
            WebSession = $Session.WebSession
            TimeoutSec = $TimeoutSec
        }
        if ($null -ne $requestBody) { $params['Body'] = $requestBody }
        if ($contentType) { $params['ContentType'] = $contentType }
        $result = Invoke-JamfSchoolHttp @params

        if ($result.StatusCode -ge 200 -and $result.StatusCode -le 299) {
            return $result.Content
        }

        $retryable = $result.StatusCode -in 429, 502, 503, 504
        if ($retryable -and $attempt -lt $MaxRetries) {
            $delaySeconds = [math]::Min([math]::Pow(2, $attempt), 30) + (Get-Random -Minimum 0.0 -Maximum 1.0)
            if ($null -ne $result.Headers -and $result.Headers.ContainsKey('Retry-After')) {
                $retryAfter = 0
                if ([int]::TryParse(@($result.Headers['Retry-After'])[0], [ref]$retryAfter)) {
                    $delaySeconds = [math]::Max($retryAfter, 1)
                }
            }
            $attempt++
            Write-Verbose "HTTP $($result.StatusCode) from Jamf School; retrying in $([math]::Round($delaySeconds, 1))s ($attempt/$MaxRetries)."
            Start-Sleep -Seconds $delaySeconds
            continue
        }

        $detail = ''
        $content = $result.Content
        if ($null -ne $content -and $content -isnot [string]) {
            $message = if ($content.PSObject.Properties.Match('message').Count -gt 0) { [string]$content.message } else { '' }
            if ($message) { $detail = " $message" }
        }
        elseif ($content -is [string] -and $content) {
            $text = ($content -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()
            if ($text.Length -gt 300) { $text = $text.Substring(0, 300) + '…' }
            $detail = " $text"
        }
        throw "Jamf School API request failed: $Method $uri returned HTTP $($result.StatusCode).$detail"
    }
}
