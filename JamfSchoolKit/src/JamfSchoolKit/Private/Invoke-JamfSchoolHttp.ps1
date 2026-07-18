function Invoke-JamfSchoolHttp {
    <#
    .SYNOPSIS
        The single HTTP seam for the module. Every network call goes through here.
    .DESCRIPTION
        Thin wrapper around Invoke-RestMethod that never throws on HTTP error status
        codes; it returns a normalized result with StatusCode, Headers and Content.
        Retry and error-shaping live in Invoke-JamfSchoolRequest, keeping this
        function trivially mockable in tests.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $Method,

        [hashtable] $Headers,

        [object] $Body,

        [string] $ContentType,

        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [Parameter(Mandatory)]
        [pscredential] $Credential,

        [int] $TimeoutSec = 300
    )

    $statusCode = 0
    $responseHeaders = $null

    $params = @{
        Uri                     = $Uri
        Method                  = $Method
        Credential              = $Credential
        Authentication          = 'Basic'
        SkipHttpErrorCheck      = $true
        StatusCodeVariable      = 'statusCode'
        ResponseHeadersVariable = 'responseHeaders'
        TimeoutSec              = $TimeoutSec
        ErrorAction             = 'Stop'
    }
    if ($null -ne $Headers -and $Headers.Count -gt 0) { $params['Headers'] = $Headers }
    if ($null -ne $Body) { $params['Body'] = $Body }
    if ($ContentType) { $params['ContentType'] = $ContentType }
    if ($null -ne $WebSession) { $params['WebSession'] = $WebSession }

    $content = Invoke-RestMethod @params

    [pscustomobject]@{
        StatusCode = [int]$statusCode
        Headers    = $responseHeaders
        Content    = $content
    }
}
