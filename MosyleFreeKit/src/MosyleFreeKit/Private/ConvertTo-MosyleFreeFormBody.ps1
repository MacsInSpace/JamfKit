function ConvertTo-MosyleFreeFormBody {
    <#
    .SYNOPSIS
        Encodes a hashtable as application/x-www-form-urlencoded.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable] $Form
    )

    $parts = foreach ($key in $Form.Keys) {
        $value = $Form[$key]
        if ($null -eq $value) { continue }
        if ($value -is [array]) {
            $value = ($value | ForEach-Object { [string]$_ }) -join ','
        }
        $encKey = [uri]::EscapeDataString([string]$key)
        $encVal = [uri]::EscapeDataString([string]$value)
        '{0}={1}' -f $encKey, $encVal
    }
    ($parts -join '&')
}
