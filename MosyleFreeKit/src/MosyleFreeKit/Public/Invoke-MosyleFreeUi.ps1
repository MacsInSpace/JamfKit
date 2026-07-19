function Invoke-MosyleFreeUi {
    <#
    .SYNOPSIS
        Calls a Mosyle Free UI PHP endpoint (generic bus — parity with Invoke-MosyleApi).
    .DESCRIPTION
        Default target is Controller/mapping.php with -Mapping and -Operation. For other
        screens, pass -Path (relative to the session BaseUri). School/OS context fields
        are injected unless already present in -Body.
    .EXAMPLE
        Invoke-MosyleFreeUi -Mapping BulkOperationsController -Operation bulk_restart -Body @{
            devices = $udid; deviceudid = $udid
        }
    .EXAMPLE
        Invoke-MosyleFreeUi -Path 'screens/scules/mdm/bulkoperations/devices_list_ajax.php' -Body @{
            page = 1; term = ''; term_by = 'true'; source_page = 'bulkoperations'
        }
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [string] $Path = 'Controller/mapping.php',

        [string] $Mapping,

        [string] $Operation,

        [hashtable] $Body,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os,

        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    $resolved = Assert-MosyleFreeSession -Session $Session
    $form = @{}
    if ($null -ne $Body) {
        foreach ($key in $Body.Keys) { $form[$key] = $Body[$key] }
    }

    if ($Mapping) { $form['mapping'] = $Mapping }
    if ($Operation) { $form['operation'] = $Operation }

    $osValue = if ($Os) { $Os } else { $resolved.Os }
    if (-not $form.ContainsKey('usertab_current_os')) {
        $form['usertab_current_os'] = $osValue
    }
    if (-not $form.ContainsKey('usertab_current_idschool')) {
        $form['usertab_current_idschool'] = $resolved.IdSchool
    }

    $uri = '{0}/{1}' -f $resolved.BaseUri.TrimEnd('/'), $Path.TrimStart('/')
    $target = if ($Operation) { "$Path ($Mapping/$Operation)" } else { $Path }

    if (-not $PSCmdlet.ShouldProcess($target, 'POST Mosyle Free UI')) {
        return [pscustomobject]@{
            PSTypeName = 'MosyleFreeKit.UiResult'
            WhatIf     = $true
            Uri        = $uri
            Form       = $form
        }
    }

    $response = Invoke-MosyleFreeHttp -Uri $uri -Method POST -WebSession $resolved.WebSession -Form $form `
        -Headers @{
            'X-Requested-With' = 'XMLHttpRequest'
            Accept             = 'application/json, text/javascript, */*'
            Referer            = "$($resolved.BaseUri.TrimEnd('/'))/"
        }

    if (Test-MosyleFreeLoginPage -RawContent $response.RawContent) {
        throw 'Mosyle Free session expired (login page returned). Re-run Connect-MosyleFree with a fresh cookie.'
    }

    [pscustomobject]@{
        PSTypeName = 'MosyleFreeKit.UiResult'
        StatusCode = $response.StatusCode
        Content    = $response.Content
        RawContent = $response.RawContent
        Uri        = $uri
    }
}
