function Remove-MosyleFreeSharedDeviceGroup {
    <#
    .SYNOPSIS
        Deletes a Mosyle Shared Device Group (HierarchyController / delete_cart).
    .DESCRIPTION
        Removes the group itself. To remove a *device* from a group without deleting the
        group, use Remove-MosyleFreeDeviceSharedGroup.
    .EXAMPLE
        Remove-MosyleFreeSharedDeviceGroup -GroupId '9' -WhatIf
    .EXAMPLE
        Get-MosyleFreeSharedDeviceGroup -Name 'FreeKit Temp' | Remove-MosyleFreeSharedDeviceGroup -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById', ValueFromPipelineByPropertyName)]
        [Alias('CartId', 'IdCart', 'Id', 'idsharedgroup')]
        [string] $GroupId,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [Alias('CartName', 'GroupName')]
        [string] $Name,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-MosyleFreeSession -Session $Session
        $osValue = if ($Os) { $Os } else { $resolved.Os }
        $ids = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ById' -and $GroupId) {
            [void]$ids.Add($GroupId)
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            $hit = @(Get-MosyleFreeSharedDeviceGroup -Name $Name -Session $resolved -Os $osValue)
            if ($hit.Count -eq 0) { throw "No Shared Device Group named '$Name'." }
            if ($hit.Count -gt 1) { throw "Multiple groups match '$Name'. Use -GroupId." }
            [void]$ids.Add($hit[0].GroupId)
        }

        if ($ids.Count -eq 0) { throw 'Supply -GroupId or -Name.' }

        foreach ($id in $ids) {
            if (-not $PSCmdlet.ShouldProcess("Shared Device Group $id", 'Delete Mosyle Free Shared Device Group')) {
                [pscustomobject]@{
                    PSTypeName = 'MosyleFreeKit.CommandResult'
                    Command    = 'RemoveSharedGroupObject'
                    Ok         = $true
                    WhatIf     = $true
                    GroupId    = $id
                }
                continue
            }

            $result = Invoke-MosyleFreeUi -Mapping HierarchyController -Operation delete_cart -Body @{
                idcart = $id
            } -Os $osValue -Session $resolved -Confirm:$false

            $ok = ($result.StatusCode -ge 200 -and $result.StatusCode -lt 300)
            if ($result.Content -is [pscustomobject] -and $result.Content.status -and $result.Content.status -ne 'OK') {
                $ok = $false
            }

            [pscustomobject]@{
                PSTypeName = 'MosyleFreeKit.CommandResult'
                Command    = 'RemoveSharedGroupObject'
                Ok         = $ok
                WhatIf     = $false
                GroupId    = $id
                StatusCode = $result.StatusCode
                Content    = $result.Content
                RawContent = $result.RawContent
            }
        }
    }
}
