function Invoke-JamfSchoolApi {
    <#
    .SYNOPSIS
        Calls any Jamf School API endpoint directly.
    .DESCRIPTION
        The escape hatch: full API surface with the module's plumbing (Basic auth,
        protocol-version header, retry/backoff, error normalization) but none of the
        typed ergonomics. Paths are relative to /api.
    .EXAMPLE
        Invoke-JamfSchoolApi -Path 'ibeacons'
    .EXAMPLE
        Invoke-JamfSchoolApi -Method POST -Path 'ibeacons' -Body @{ name = 'Library'; uuid = $uuid; major = 1; minor = 2 }
    .EXAMPLE
        Invoke-JamfSchoolApi -Path 'devices' -Query @{ ownergroups = '12' } -ProtocolVersion 2
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path,

        [Parameter(Position = 1)]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')]
        [string] $Method = 'GET',

        [object] $Body,

        [hashtable] $Query,

        [int] $ProtocolVersion = 0,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    $resolved = Assert-JamfSchoolSession -Session $Session

    if ($Method -eq 'GET' -or $PSCmdlet.ShouldProcess("$($resolved.BaseUri)/api/$($Path.Trim('/'))", $Method)) {
        $params = @{
            Session = $resolved
            Method  = $Method
            Path    = $Path
        }
        if ($null -ne $Body) { $params['Body'] = $Body }
        if ($null -ne $Query) { $params['Query'] = $Query }
        if ($ProtocolVersion -gt 0) { $params['ProtocolVersion'] = $ProtocolVersion }
        Invoke-JamfSchoolRequest @params
    }
}
