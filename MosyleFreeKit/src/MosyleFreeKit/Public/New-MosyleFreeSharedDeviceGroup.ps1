function New-MosyleFreeSharedDeviceGroup {
    <#
    .SYNOPSIS
        Creates a Mosyle Shared Device Group (HierarchyController / save_cart).
    .DESCRIPTION
        Fetches cart_form.php for a fresh NotesToken, then posts save_cart with idcart=0.
        Returns the new GroupId when Mosyle includes it in the JSON response.
    .PARAMETER LocationId
        Location unit id(s) allowed to manage the group. Sent as idunits JSON array.
        Defaults to 1 when omitted (the Free test tenant single-location schools).
    .EXAMPLE
        New-MosyleFreeSharedDeviceGroup -Name 'FreeKit Temp' -LocationId 1 -WhatIf
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [Alias('CartName', 'GroupName')]
        [string] $Name,

        [ValidateSet('CART', 'LAB', 'OTHER')]
        [string] $GroupType = 'CART',

        [Alias('IdUnit', 'idunits')]
        [string[]] $LocationId = @('1'),

        [switch] $LocationEnabled,

        [switch] $AppleShared,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    $resolved = Assert-MosyleFreeSession -Session $Session
    $osValue = if ($Os) { $Os } else { $resolved.Os }
    $base = $resolved.BaseUri.TrimEnd('/')

    if (-not $PSCmdlet.ShouldProcess($Name, 'Create Mosyle Free Shared Device Group')) {
        return [pscustomobject]@{
            PSTypeName = 'MosyleFreeKit.CommandResult'
            Command    = 'NewSharedGroup'
            Ok         = $true
            WhatIf     = $true
            Name       = $Name
        }
    }

    $formHtml = Invoke-MosyleFreeHttp -Uri "$base/screens/scules/hierarchy/cart_form.php" -Method POST `
        -WebSession $resolved.WebSession -Form @{
        usertab_current_os       = $osValue
        usertab_current_idschool = $resolved.IdSchool
    } -Headers @{
        'X-Requested-With' = 'XMLHttpRequest'
        Referer            = "$base/"
    }

    $token = $null
    $tok = [regex]::Match($formHtml.RawContent, 'name="NotesToken"\s+value="([^"]+)"')
    if ($tok.Success) { $token = $tok.Groups[1].Value }

    $unitIds = @($LocationId | ForEach-Object { "$_".Trim() } | Where-Object { $_ })
    if ($unitIds.Count -eq 0) { throw 'Supply at least one -LocationId.' }
    $idunits = '[{0}]' -f (($unitIds | ForEach-Object { $_ }) -join ',')

    $body = @{
        operation      = 'save_cart'
        mapping        = 'HierarchyController'
        idcart         = '0'
        mdm_platform   = $osValue
        cart_name      = $Name
        group_type     = $GroupType
        NotesToken     = $(if ($token) { $token } else { '' })
        idunits        = $idunits
        idclassperiods = '[]'
        deviceudids    = '[]'
    }
    if ($LocationEnabled) { $body['is_location_enabled'] = '1' }
    if ($AppleShared) { $body['is_apple_shared'] = '1' }

    $result = Invoke-MosyleFreeUi -Mapping HierarchyController -Operation save_cart -Body $body `
        -Os $osValue -Session $resolved -Confirm:$false

    $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
    $newId = $null
    $newName = $Name
    if ($result.Content -is [pscustomobject]) {
        if ($result.Content.status -and $result.Content.status -ne 'OK') { $ok = $false }
        if ($result.Content.idcart) { $newId = [string]$result.Content.idcart }
        if ($result.Content.cartname) { $newName = [string]$result.Content.cartname }
    }

    [pscustomobject]@{
        PSTypeName = 'MosyleFreeKit.CommandResult'
        Command    = 'NewSharedGroup'
        Ok         = $ok
        WhatIf     = $false
        GroupId    = $newId
        Name       = $newName
        StatusCode = $result.StatusCode
        Content    = $result.Content
        RawContent = $result.RawContent
    }
}
