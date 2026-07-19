function ConvertTo-MosyleFreeDeviceObject {
    <#
    .SYNOPSIS
        Normalizes a devices_list_ajax.php device row into MosyleFreeKit.Device.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Raw
    )

    if (-not $Raw -or -not $Raw.PSObject -or -not $Raw.PSObject.Properties['deviceudid']) {
        return $null
    }
    $udid = [string]$Raw.deviceudid
    if (-not $udid) { return $null }

    $obj = $Raw | Select-Object *
    $obj.PSObject.TypeNames.Insert(0, 'MosyleFreeKit.Device')
    $obj | Add-Member -NotePropertyName UDID -NotePropertyValue $udid -Force
    $obj
}
