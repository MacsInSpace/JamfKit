function Get-MosyleFreeSharedDeviceGroup {
    <#
    .SYNOPSIS
        Lists Mosyle Shared Device Groups (name ↔ id mapping).
    .DESCRIPTION
        Free UI: My School → Shared Device Groups (legacy “Shared Device Carts”).
        Loads screens/scules/hierarchy/carts_list.php and enriches with
        HierarchyController / carts_info (idcart as JSON array).

        Use GroupId with Add-MosyleFreeDeviceSharedGroup / Remove-MosyleFreeDeviceSharedGroup.
    .EXAMPLE
        Get-MosyleFreeSharedDeviceGroup
    .EXAMPLE
        Get-MosyleFreeSharedDeviceGroup -Name 'Student Devices'
    #>
    [CmdletBinding()]
    param(
        [Alias('CartName', 'GroupName')]
        [string] $Name,

        [Alias('CartId', 'IdCart', 'idsharedgroup', 'GroupId')]
        [string] $Id,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    $resolved = Assert-MosyleFreeSession -Session $Session
    $osValue = if ($Os) { $Os } else { $resolved.Os }
    $base = $resolved.BaseUri.TrimEnd('/')
    $listUri = "$base/screens/scules/hierarchy/carts_list.php"

    $list = Invoke-MosyleFreeHttp -Uri $listUri -Method POST -WebSession $resolved.WebSession -Form @{
        usertab_current_os       = $osValue
        usertab_current_idschool = $resolved.IdSchool
    } -Headers @{
        'X-Requested-With' = 'XMLHttpRequest'
        Accept             = 'text/html, */*'
        Referer            = "$base/"
    }

    if (Test-MosyleFreeLoginPage -RawContent $list.RawContent) {
        throw 'Mosyle Free session expired (login page returned). Re-run Connect-MosyleFree with a fresh cookie.'
    }

    $groups = @(ConvertFrom-MosyleFreeSharedGroupsHtml -Html $list.RawContent)
    if ($groups.Count -eq 0) {
        return
    }

    $idList = ($groups.GroupId | ForEach-Object { $_ }) -join ','
    $info = Invoke-MosyleFreeUi -Mapping HierarchyController -Operation carts_info -Body @{
        idcart = "[$idList]"
    } -Os $osValue -Session $resolved -Confirm:$false

    $byId = @{}
    if ($info.Content -and $info.Content.response) {
        $resp = $info.Content.response
        foreach ($prop in $resp.PSObject.Properties) {
            $byId[$prop.Name] = $prop.Value
        }
    }

    foreach ($g in $groups) {
        $extra = $byId[$g.GroupId]
        if ($extra) {
            if ($extra.cart_name) { $g.Name = [string]$extra.cart_name; $g.CartName = $g.Name }
            $g | Add-Member -NotePropertyName AccountId -NotePropertyValue $extra.idaccount -Force
            $g | Add-Member -NotePropertyName Locations -NotePropertyValue $extra.locations -Force
        }

        $match = $true
        if ($Id -and $g.GroupId -ne $Id) { $match = $false }
        if ($Name -and $g.Name -notlike $Name) { $match = $false }
        if ($match) { $g }
    }
}
