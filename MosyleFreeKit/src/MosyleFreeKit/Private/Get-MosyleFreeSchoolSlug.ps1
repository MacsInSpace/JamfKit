function Get-MosyleFreeSchoolSlug {
    <#
    .SYNOPSIS
        Reads usertab_current_idschool out of a Mosyle UI page.
    .DESCRIPTION
        The signed-in landing page carries the school slug in a hidden input:

            <input type="hidden" name="usertab_current_idschool" value="yourschool"/>

        Recovering it there means the caller never has to know or type it.
        Returns $null when the page does not carry one (e.g. a login page).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Html
    )

    if ([string]::IsNullOrWhiteSpace($Html)) { return $null }

    $patterns = @(
        'name="usertab_current_idschool"[^>]*\bvalue="([^"]+)"'
        'id="usertab_current_idschool"[^>]*\bvalue="([^"]+)"'
        '\bvalue="([^"]+)"[^>]*name="usertab_current_idschool"'
        'usertab_current_idschool["'']?\s*[:=]\s*["'']([A-Za-z0-9_.-]+)["'']'
    )

    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Html, $pattern)
        if ($match.Success) {
            $slug = $match.Groups[1].Value.Trim()
            if ($slug) { return $slug }
        }
    }

    return $null
}
