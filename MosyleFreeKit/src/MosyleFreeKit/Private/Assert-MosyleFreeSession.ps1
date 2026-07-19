function Assert-MosyleFreeSession {
    <#
    .SYNOPSIS
        Resolves the session a cmdlet should use, or throws a friendly error.
    #>
    [CmdletBinding()]
    param(
        [object] $Session
    )

    if ($null -ne $Session) {
        if ($Session.PSObject.TypeNames -notcontains 'MosyleFreeKit.Session') {
            throw 'The supplied -Session object is not a MosyleFreeKit session. Use Connect-MosyleFree to create one.'
        }
        return $Session
    }
    if ($null -ne $script:DefaultMosyleFreeSession) {
        return $script:DefaultMosyleFreeSession
    }
    throw 'Not connected to Mosyle Free UI. Run Connect-MosyleFree first (session cookie / WebSession).'
}
