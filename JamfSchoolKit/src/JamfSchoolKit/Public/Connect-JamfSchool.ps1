function Connect-JamfSchool {
    <#
    .SYNOPSIS
        Connects to a Jamf School instance and creates the module's default session.
    .DESCRIPTION
        The Jamf School API authenticates every request with HTTP Basic auth:
        username = your Network ID (Devices > Enroll Device(s)), password = an API key
        (Settings > API). There is no token exchange and keys do not expire, so the
        session simply carries the credential.

        The connection is verified with a lightweight request. Every call sends
        X-Server-Protocol-Version (default 3) — the API silently falls back to the
        ancient v1 response shapes when the header is missing.
    .PARAMETER Url
        Base URL of the instance, e.g. https://yourschool.jamfcloud.com
    .PARAMETER NetworkId
        The Network ID used as the Basic auth username.
    .PARAMETER ApiKey
        The API key as a SecureString (e.g. from Get-Secret).
    .PARAMETER Credential
        Alternative to NetworkId/ApiKey: a PSCredential holding both.
    .PARAMETER ProtocolVersion
        Default X-Server-Protocol-Version for the session (1-4, default 3).
    .EXAMPLE
        Connect-JamfSchool -Url https://school.jamfcloud.com -NetworkId 1234567890 -ApiKey (Get-Secret JamfSchool)
    .EXAMPLE
        $test = Connect-JamfSchool -Url https://test.jamfcloud.com -Credential $cred -PassThru
        Get-JamfSchoolDevice -Session $test
    #>
    [CmdletBinding(DefaultParameterSetName = 'Key')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^https?://')]
        [string] $Url,

        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [string] $NetworkId,

        [Parameter(Mandatory, ParameterSetName = 'Key')]
        [securestring] $ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [pscredential] $Credential,

        [ValidateRange(1, 4)]
        [int] $ProtocolVersion = 3,

        [switch] $PassThru
    )

    $sessionCredential = if ($PSCmdlet.ParameterSetName -eq 'Key') {
        [pscredential]::new($NetworkId, $ApiKey)
    }
    else {
        $Credential
    }

    $session = [pscustomobject]@{
        PSTypeName      = 'JamfSchoolKit.Session'
        BaseUri         = $Url.TrimEnd('/')
        Credential      = $sessionCredential
        ProtocolVersion = $ProtocolVersion
        WebSession      = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
    }

    # Verify the credential with the cheapest meaningful read.
    $null = Invoke-JamfSchoolRequest -Session $session -Method GET -Path 'devices' -Query @{ limit = 1 }

    $script:DefaultJamfSchoolSession = $session
    Write-Verbose "Connected to $($session.BaseUri) (Jamf School, protocol v$ProtocolVersion)."

    if ($PassThru) { return $session }
}
