function ConvertFrom-MosyleFreeSharedGroupsHtml {
    <#
    .SYNOPSIS
        Parses screens/scules/hierarchy/carts_list.php HTML into group objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Html
    )

    $groups = [System.Collections.Generic.List[object]]::new()
    $liPattern = [regex]'(?s)<li\s+id="group_(\d+)"[^>]*>(.*?)</li>'
    foreach ($m in $liPattern.Matches($Html)) {
        $id = $m.Groups[1].Value
        $block = $m.Groups[2].Value

        $name = $null
        $title = [regex]::Match($block, '(?s)<div class="title">\s*<img[^>]*>\s*([^<]+)')
        if ($title.Success) {
            $name = $title.Groups[1].Value.Trim()
        }

        $count = $null
        $cnt = [regex]::Match($block, '(?s)<div class="count-elements[^"]*">\s*(\d+)\s*<span>devices</span>')
        if ($cnt.Success) {
            $count = [int]$cnt.Groups[1].Value
        }

        $groups.Add([pscustomobject]@{
                PSTypeName    = 'MosyleFreeKit.SharedDeviceGroup'
                GroupId       = $id
                IdCart        = $id
                Name          = $name
                DeviceCount   = $count
                CartName      = $name
            })
    }

    $groups
}
