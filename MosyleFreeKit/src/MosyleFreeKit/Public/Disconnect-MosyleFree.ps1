function Disconnect-MosyleFree {
    <#
    .SYNOPSIS
        Clears the module's default Mosyle Free UI session.
    .EXAMPLE
        Disconnect-MosyleFree
    #>
    [CmdletBinding()]
    param(
        [PSTypeName('MosyleFreeKit.Session')]
        [object] $Session
    )

    $target = if ($null -ne $Session) { $Session } else { $script:DefaultMosyleFreeSession }
    if ($null -eq $target) {
        Write-Verbose 'No active Mosyle Free session to disconnect.'
        return
    }

    $target.WebSession = $null
    $target.AdminCredential = $null

    if ($script:DefaultMosyleFreeSession -eq $target) {
        $script:DefaultMosyleFreeSession = $null
    }
}
