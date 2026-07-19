function ConvertFrom-MosyleFreeDeviceCommandsHtml {
    <#
    .SYNOPSIS
        Parses deviceinfo/device_commands.php HTML into command row objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Html,

        [string] $Device,

        [string] $SerialNumber
    )

    $plain = [regex]::Replace($Html, '(?is)<script[^>]*>.*?</script>', ' ')
    $plain = [regex]::Replace($plain, '(?is)<style[^>]*>.*?</style>', ' ')
    $plain = [regex]::Replace($plain, '(?is)<[^>]+>', ' ')
    $plain = [regex]::Replace($plain, '\s+', ' ').Trim()

    if ($plain -match '(?i)There are no pending or failed commands') {
        return @()
    }

    $rows = [System.Collections.Generic.List[object]]::new()
    # e.g. "Pending Command Shutdown Device System-Scope Shutdown Device Date created: 12:59 AM - 19/07/26 Date last connection: 07:36 PM - 11/08/21"
    $pattern = '(?i)(?<status>Pending|Failed)\s+Command\s+(?<label>.+?)\s+System-Scope\s+(?<detail>.+?)\s+Date created:\s*(?<created>.+?)\s+Date last connection:\s*(?<last>.+?)(?=\s+(?:Pending|Failed)\s+Command|\s*$)'
    foreach ($m in [regex]::Matches($plain, $pattern)) {
        $label = ($m.Groups['label'].Value).Trim()
        $detail = ($m.Groups['detail'].Value).Trim()
        $rows.Add([pscustomobject]@{
                PSTypeName     = 'MosyleFreeKit.DeviceCommand'
                Status         = (Get-Culture).TextInfo.ToTitleCase($m.Groups['status'].Value.ToLowerInvariant())
                Label          = $label
                Detail         = $detail
                Scope          = 'System-Scope'
                Created        = ($m.Groups['created'].Value).Trim()
                LastConnection = ($m.Groups['last'].Value).Trim()
                Device         = $Device
                SerialNumber   = $SerialNumber
            })
    }

    # Fallback: looser split if System-Scope pattern missed (still count Pending Command markers)
    if ($rows.Count -eq 0 -and $plain -match '(?i)Pending Command') {
        foreach ($chunk in [regex]::Split($plain, '(?i)(?=Pending Command|Failed Command)')) {
            if ($chunk -notmatch '(?i)^(Pending|Failed)\s+Command\s+(.+)$') { continue }
            $status = $Matches[1]
            $rest = $Matches[2].Trim()
            $created = $null
            $last = $null
            if ($rest -match '(?i)Date created:\s*(.+?)\s+Date last connection:\s*(.+)$') {
                $created = $Matches[1].Trim()
                $last = $Matches[2].Trim()
                $rest = ($rest -replace '(?i)\s*Date created:.*$', '').Trim()
            }
            $label = ($rest -replace '(?i)\s*System-Scope.*$', '').Trim()
            if (-not $label) { continue }
            $rows.Add([pscustomobject]@{
                    PSTypeName     = 'MosyleFreeKit.DeviceCommand'
                    Status         = (Get-Culture).TextInfo.ToTitleCase($status.ToLowerInvariant())
                    Label          = $label
                    Detail         = $rest
                    Scope          = if ($rest -match 'System-Scope') { 'System-Scope' } else { $null }
                    Created        = $created
                    LastConnection = $last
                    Device         = $Device
                    SerialNumber   = $SerialNumber
                })
        }
    }

    @($rows)
}
