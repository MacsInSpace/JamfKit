function Merge-JamfExtensionAttributeInput {
    <#
    .SYNOPSIS
        Merges MUT-style EA_<id> CSV columns with an explicit -ExtensionAttribute hashtable.
    .DESCRIPTION
        The MUT templates append extension attribute columns named EA_<id> (e.g. EA_2)
        after the fixed columns. Pipeline property binding cannot capture arbitrary
        column names, so bulk cmdlets also take the whole row via -InputObject and pass
        it here. Explicit -ExtensionAttribute values win over CSV columns.
        Returns a hashtable of [int] EA id -> [string] value.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [object] $InputObject,

        [hashtable] $ExtensionAttribute
    )

    $merged = @{}

    if ($null -ne $InputObject) {
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.Name -match '^EA_(\d+)$') {
                $merged[[int]$Matches[1]] = [string]$property.Value
            }
        }
    }

    if ($null -ne $ExtensionAttribute) {
        foreach ($key in $ExtensionAttribute.Keys) {
            $merged[[int]$key] = [string]$ExtensionAttribute[$key]
        }
    }

    $merged
}
