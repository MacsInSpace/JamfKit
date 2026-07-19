function Get-MosyleFreeDevice {
    <#
    .SYNOPSIS
        Lists devices from the Mosyle Free UI (devices_list_ajax.php).
    .DESCRIPTION
        Walks pages until a page returns no new devices, or -Page is set for a single
        page (1-based, matching the UI).

        When -SerialNumber or -Term is supplied, Free's list endpoint is queried with the
        proven search fields (term / search / search_text / last_search). If serial lookup
        is incomplete, falls back to a page walk and client-side serial filter.
    .PARAMETER Os
        Platform: ios, mac, tvos, visionos.
    .PARAMETER Page
        Single 1-based page. Omit to return all pages (ignored when resolving -SerialNumber).
    .PARAMETER Term
        Search term passed to the UI list endpoint.
    .PARAMETER SerialNumber
        Resolve these serials (server-side lookup first, then client-side filter fallback).
        Accepts pipeline input (string serials or objects with serial_number).
    .EXAMPLE
        Get-MosyleFreeDevice -Os ios
    .EXAMPLE
        Get-MosyleFreeDevice -Os ios -SerialNumber MNOP9012QRST, ABCD1234EFGH
    .EXAMPLE
        'ABCD1234EFGH', 'WXYZ5678IJKL' | Get-MosyleFreeDevice -Os ios
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [int] $Page,

        [string] $Term,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('serial_number', 'Serial')]
        [string[]] $SerialNumber,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-MosyleFreeSession -Session $Session
        $osValue = if ($Os) { $Os } else { $resolved.Os }
        $serials = [System.Collections.Generic.List[string]]::new()
        $listPath = 'screens/scules/mdm/bulkoperations/devices_list_ajax.php'
    }

    process {
        if ($null -ne $SerialNumber) {
            foreach ($sn in $SerialNumber) {
                if ([string]::IsNullOrWhiteSpace($sn)) { continue }
                [void]$serials.Add($sn.Trim())
            }
        }
        elseif ($_ -and $_.PSObject.Properties['serial_number'] -and $_.serial_number) {
            [void]$serials.Add([string]$_.serial_number)
        }
    }

    end {
        $invokeList = {
            param([hashtable] $Body)
            $result = Invoke-MosyleFreeUi -Path $listPath -Body $Body -Session $resolved -Confirm:$false
            if ($result.StatusCode -lt 200 -or $result.StatusCode -ge 300) {
                throw "List devices failed: HTTP $($result.StatusCode) — $($result.RawContent)"
            }
            # Empty devices:[] is falsy in PowerShell. Returning bare @() unrolls to $null
            # (StrictMode .Count fails). Return a List with unary comma so callers get
            # a real object — do NOT wrap the call site in @(...), which re-nests empties.
            $devices = [System.Collections.Generic.List[object]]::new()
            if ($result.Content -is [pscustomobject] -and
                $result.Content.PSObject.Properties['MDMResponse'] -and
                $result.Content.MDMResponse -and
                $result.Content.MDMResponse.PSObject.Properties['devices'] -and
                $null -ne $result.Content.MDMResponse.devices) {
                foreach ($d in @($result.Content.MDMResponse.devices)) {
                    [void]$devices.Add($d)
                }
            }
            return , $devices
        }.GetNewClosure()

        $newBody = {
            param([int] $PageNum = 1, [string] $Search = '')
            $body = @{
                page                     = [string]$PageNum
                source_page              = 'bulkoperations'
                input_type               = 'checkbox'
                search_text_by           = '1'
                usertab_current_os       = $osValue
                usertab_current_idschool = $resolved.IdSchool
            }
            if ($Search) {
                $body['term'] = $Search
                $body['search'] = $Search
                $body['search_text'] = $Search
                $body['last_search'] = 'serial_number'
            }
            else {
                $body['term'] = ''
            }
            $body
        }.GetNewClosure()

        if ($serials.Count -gt 0) {
            $want = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]$serials,
                [StringComparer]::OrdinalIgnoreCase
            )
            $found = [System.Collections.Generic.List[object]]::new()
            $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

            foreach ($sn in $want) {
                $batch = & $invokeList (& $newBody -PageNum 1 -Search $sn)
                if ($null -eq $batch) { $batch = [System.Collections.Generic.List[object]]::new() }
                $match = @(
                    $batch | Where-Object {
                        $_.serial_number -and ([string]$_.serial_number).Equals($sn, [StringComparison]::OrdinalIgnoreCase)
                    }
                )
                if ($match.Count -eq 0 -and $batch.Count -eq 1) {
                    $match = @($batch[0])
                }
                foreach ($d in $match) {
                    $obj = ConvertTo-MosyleFreeDeviceObject -Raw $d
                    if (-not $obj) { continue }
                    if (-not $seen.Add($obj.UDID)) { continue }
                    [void]$found.Add($obj)
                }
            }

            if ($found.Count -lt $want.Count) {
                $haveSerials = [System.Collections.Generic.HashSet[string]]::new(
                    [string[]](@($found | ForEach-Object { [string]$_.serial_number } | Where-Object { $_ })),
                    [StringComparer]::OrdinalIgnoreCase
                )
                for ($pageNum = 1; $pageNum -le 200; $pageNum++) {
                    $batch = & $invokeList (& $newBody -PageNum $pageNum)
                    if ($null -eq $batch) { $batch = [System.Collections.Generic.List[object]]::new() }
                    if ($batch.Count -eq 0) { break }
                    foreach ($d in $batch) {
                        $sn = [string]$d.serial_number
                        if (-not $sn -or -not $want.Contains($sn)) { continue }
                        $obj = ConvertTo-MosyleFreeDeviceObject -Raw $d
                        if (-not $obj) { continue }
                        if (-not $seen.Add($obj.UDID)) { continue }
                        [void]$found.Add($obj)
                        [void]$haveSerials.Add($sn)
                    }
                    if ($haveSerials.Count -ge $want.Count) { break }
                }
            }

            return @($found)
        }

        if ($Term) {
            $devices = [System.Collections.Generic.List[object]]::new()
            $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $batch = & $invokeList (& $newBody -PageNum 1 -Search $Term)
            if ($null -eq $batch) { $batch = [System.Collections.Generic.List[object]]::new() }
            foreach ($d in $batch) {
                $obj = ConvertTo-MosyleFreeDeviceObject -Raw $d
                if (-not $obj) { continue }
                if (-not $seen.Add($obj.UDID)) { continue }
                [void]$devices.Add($obj)
            }
            return @($devices)
        }

        $devices = [System.Collections.Generic.List[object]]::new()
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $startPage = if ($PSBoundParameters.ContainsKey('Page')) { $Page } else { 1 }
        $endPage = if ($PSBoundParameters.ContainsKey('Page')) { $Page } else { 200 }

        for ($pageNum = $startPage; $pageNum -le $endPage; $pageNum++) {
            $batch = & $invokeList (& $newBody -PageNum $pageNum)
            if ($null -eq $batch) { $batch = [System.Collections.Generic.List[object]]::new() }
            if ($batch.Count -eq 0) { break }

            $added = 0
            foreach ($d in $batch) {
                $obj = ConvertTo-MosyleFreeDeviceObject -Raw $d
                if (-not $obj) { continue }
                if (-not $seen.Add($obj.UDID)) { continue }
                [void]$devices.Add($obj)
                $added++
            }

            if ($PSBoundParameters.ContainsKey('Page')) { break }
            if ($added -eq 0) { break }
        }

        @($devices)
    }
}
