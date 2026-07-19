function Get-MosyleFreeSession {
    <#
    .SYNOPSIS
        Returns the current default Mosyle Free UI session, if connected.
    .EXAMPLE
        Get-MosyleFreeSession
    #>
    [CmdletBinding()]
    param()

    $script:DefaultMosyleFreeSession
}
