function Invoke-MosyleFreeHttp {
    <#
    .SYNOPSIS
        The single HTTP seam for MosyleFreeKit. Every network call goes through here.
    .DESCRIPTION
        Thin wrapper around Invoke-WebRequest using a WebRequestSession (cookie jar).
        Defaults to application/x-www-form-urlencoded POSTs against myschool.mosyle.com.
        Never throws on HTTP error status; callers interpret StatusCode / Content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [ValidateSet('GET', 'POST')]
        [string] $Method = 'POST',

        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [hashtable] $Headers,

        [hashtable] $Form,

        [string] $Body,

        [string] $ContentType = 'application/x-www-form-urlencoded',

        [int] $TimeoutSec = 120
    )

    $params = @{
        Uri                = $Uri
        Method             = $Method
        SkipHttpErrorCheck = $true
        TimeoutSec         = $TimeoutSec
        ErrorAction        = 'Stop'
    }
    if ($null -ne $WebSession) { $params['WebSession'] = $WebSession }
    if ($null -ne $Headers -and $Headers.Count -gt 0) { $params['Headers'] = $Headers }

    if ($Method -eq 'POST') {
        if ($null -ne $Form) {
            $params['Body'] = ConvertTo-MosyleFreeFormBody -Form $Form
            $params['ContentType'] = $ContentType
        }
        elseif ($PSBoundParameters.ContainsKey('Body')) {
            $params['Body'] = $Body
            $params['ContentType'] = $ContentType
        }
    }

    $response = Invoke-WebRequest @params

    $content = $null
    if ($response.Content) {
        $raw = [string]$response.Content
        if ($raw.TrimStart().StartsWith('{') -or $raw.TrimStart().StartsWith('[')) {
            try { $content = $raw | ConvertFrom-Json }
            catch { $content = $raw }
        }
        else {
            $content = $raw
        }
    }

    [pscustomobject]@{
        StatusCode = [int]$response.StatusCode
        Headers    = $response.Headers
        Content    = $content
        RawContent = if ($response.Content) { [string]$response.Content } else { $null }
    }
}
