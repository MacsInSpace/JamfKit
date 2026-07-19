function Connect-MosyleFree {
    <#
    .SYNOPSIS
        Connects to a Mosyle Manager Free school using your browser session.
    .DESCRIPTION
        Free schools have no managerapi.mosyle.com access token, so this module reuses the
        same web session your browser holds on myschool.mosyle.com.

        Run it with no arguments and it walks you through the one-time cookie grab:

            Connect-MosyleFree

        You can paste any of these and it will work out the rest:

          * the whole "Copy as cURL" blob from DevTools > Network (easiest - it carries
            the school slug too, so you never have to look up -IdSchool)
          * a Cookie header:  Cookie: PHPSESSID=...; credentials=...
          * a single pair:    PHPSESSID=...
          * rows copied from DevTools > Application > Cookies
          * JSON from a cookie-export extension

        The session cookies are HttpOnly, so document.cookie will not show them - they
        have to come from DevTools or an export add-on.

        -SaveCookie writes the working cookie to disk (0600) so later runs just work;
        subsequent connects find it automatically.
    .PARAMETER IdSchool
        usertab_current_idschool value. Optional - detected from the signed-in page, or
        from a pasted cURL, when omitted.
    .PARAMETER Cookie
        Cookie text in any supported format (see description).
    .PARAMETER CookieFile
        Path to a file holding that same cookie text. Defaults to $env:MOSYLEFREEKIT_COOKIE,
        then ./secrets/cookie.txt, then ~/.mosylefreekit/cookie.txt.
    .PARAMETER WebSession
        An existing Microsoft.PowerShell.Commands.WebRequestSession to reuse.
    .PARAMETER Os
        Default platform context for list/command calls (ios, mac, tvos, visionos).
    .PARAMETER Url
        UI base URL. Defaults to https://myschool.mosyle.com
    .PARAMETER AdminCredential
        Mosyle admin password used for ops that raise the security-confirm dialog
        (Restart / Lock / Wipe / Lost Mode).
    .PARAMETER SaveCookie
        Persist the cookie that just worked to ~/.mosylefreekit/cookie.txt (0600).
    .PARAMETER SkipValidation
        Skip the post-connect device-list probe.
    .EXAMPLE
        Connect-MosyleFree
        Guided first run: prompts for the paste, detects the school, validates, done.
    .EXAMPLE
        Connect-MosyleFree -Cookie 'PHPSESSID=abc123' -SaveCookie
    .EXAMPLE
        Connect-MosyleFree -IdSchool yourschool -CookieFile ./secrets/cookie.txt -Os ios
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Interactive first-run walkthrough is console UI, not pipeline output.')]
    [CmdletBinding(DefaultParameterSetName = 'Cookie')]
    param(
        [string] $IdSchool,

        [Parameter(ParameterSetName = 'Cookie')]
        [string] $Cookie,

        [Parameter(ParameterSetName = 'CookieFile')]
        [string] $CookieFile,

        [Parameter(Mandatory, ParameterSetName = 'WebSession')]
        [Microsoft.PowerShell.Commands.WebRequestSession] $WebSession,

        [ValidateSet('ios', 'mac', 'tvos', 'visionos')]
        [string] $Os = 'ios',

        [ValidatePattern('^https?://')]
        [string] $Url = 'https://myschool.mosyle.com',

        [pscredential] $AdminCredential,

        [switch] $SaveCookie,

        [switch] $SkipValidation,

        [switch] $PassThru
    )

    $base = $Url.TrimEnd('/')
    $baseUri = [uri]"$base/"
    $defaultCookiePath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.mosylefreekit' 'cookie.txt'
    $cookieText = $null
    $cookieOrigin = 'the supplied web session'

    if ($PSCmdlet.ParameterSetName -ne 'WebSession') {
        if ($Cookie) {
            $cookieText = $Cookie
            $cookieOrigin = 'the -Cookie parameter'
        }
        elseif ($CookieFile) {
            if (-not (Test-Path -LiteralPath $CookieFile)) {
                throw "Cookie file not found: $CookieFile"
            }
            $cookieText = Get-Content -LiteralPath $CookieFile -Raw
            $cookieOrigin = $CookieFile
        }
        else {
            # Somewhere we have been told to look, or saved to before.
            $candidates = @(
                $env:MOSYLEFREEKIT_COOKIE
                (Join-Path (Get-Location).Path 'secrets' 'cookie.txt')
                $defaultCookiePath
            ) | Where-Object { $_ }

            foreach ($candidate in $candidates) {
                if (Test-Path -LiteralPath $candidate) {
                    $cookieText = Get-Content -LiteralPath $candidate -Raw
                    $cookieOrigin = $candidate
                    Write-Verbose "Using saved cookie from $candidate"
                    break
                }
            }
        }

        # Nothing to go on - walk the user through the one-time grab.
        if (-not $cookieText) {
            if (-not [Environment]::UserInteractive) {
                throw 'No cookie available. Pass -Cookie or -CookieFile, or set MOSYLEFREEKIT_COOKIE. See docs/AUTH.md.'
            }

            Write-Host ''
            Write-Host 'Connect to Mosyle Manager Free' -ForegroundColor Cyan
            Write-Host '------------------------------'
            Write-Host "Mosyle's session cookies are HttpOnly, so they have to come from DevTools."
            Write-Host ''
            Write-Host "  1. Sign in to $base as a school admin." -ForegroundColor Yellow
            Write-Host '  2. Open DevTools (F12) and click the Network tab.' -ForegroundColor Yellow
            Write-Host '  3. Click anything in the Mosyle UI so a request appears.' -ForegroundColor Yellow
            Write-Host '  4. Right-click that request > Copy > Copy as cURL.' -ForegroundColor Yellow
            Write-Host ''
            Write-Host '  Paste it below, then press Enter on a blank line.'
            Write-Host '  (A plain "PHPSESSID=..." works too.)' -ForegroundColor DarkGray
            Write-Host ''

            $lines = [System.Collections.Generic.List[string]]::new()
            while ($true) {
                $line = Read-Host '  paste'
                if ([string]::IsNullOrWhiteSpace($line)) { break }
                [void]$lines.Add($line)
            }
            $cookieText = $lines -join "`n"
            $cookieOrigin = 'your paste'

            if (-not $cookieText.Trim()) {
                throw 'Nothing pasted. Re-run Connect-MosyleFree once you have the cookie.'
            }
        }

        $parsed = ConvertFrom-MosyleFreeCookieInput -InputText $cookieText
        $WebSession = New-MosyleFreeWebSession -Cookies $parsed.Cookies -BaseUri $baseUri

        if (-not $IdSchool -and $parsed.IdSchool) {
            $IdSchool = $parsed.IdSchool
            Write-Verbose "Detected school '$IdSchool' from the pasted request."
        }

        $names = @($parsed.Cookies.Keys)
        Write-Verbose "Loaded $($names.Count) cookie(s) from $cookieOrigin : $($names -join ', ')"
        if ($names -notcontains 'PHPSESSID' -and $names -notcontains 'credentials') {
            Write-Warning "Neither PHPSESSID nor credentials was found in $cookieOrigin. Mosyle will probably reject this session."
        }
    }

    # Always hit the UI once: it lands Set-Cookie PHPSESSID in the jar and names the school.
    $probe = Invoke-MosyleFreeHttp -Uri "$base/" -Method GET -WebSession $WebSession

    if (Test-MosyleFreeLoginPage -RawContent $probe.RawContent) {
        throw "Session cookie was rejected - Mosyle returned the login page. The cookie from $cookieOrigin is expired or from a different browser profile. Grab a fresh one from a signed-in tab and try again."
    }

    if (-not $IdSchool) {
        $IdSchool = Get-MosyleFreeSchoolSlug -Html $probe.RawContent
        if ($IdSchool) {
            Write-Verbose "Detected school '$IdSchool' from the signed-in page."
        }
        else {
            throw 'Could not detect the school slug. Pass -IdSchool explicitly (it is the usertab_current_idschool value in the Mosyle page source).'
        }
    }

    $session = [pscustomobject]@{
        PSTypeName      = 'MosyleFreeKit.Session'
        BaseUri         = $base
        IdSchool        = $IdSchool
        Os              = $Os
        WebSession      = $WebSession
        AdminCredential = $AdminCredential
        ConnectedAt     = [DateTimeOffset]::UtcNow
    }

    if (-not $SkipValidation) {
        $listUri = "$base/screens/scules/mdm/bulkoperations/devices_list_ajax.php"
        $form = @{
            usertab_current_os       = $Os
            usertab_current_idschool = $IdSchool
            page                     = '1'
            term                     = ''
            term_by                  = 'true'
            source_page              = 'bulkoperations'
        }
        $list = Invoke-MosyleFreeHttp -Uri $listUri -Method POST -WebSession $WebSession -Form $form `
            -Headers @{ 'X-Requested-With' = 'XMLHttpRequest'; Referer = "$base/" }

        if (Test-MosyleFreeLoginPage -RawContent $list.RawContent) {
            throw 'Session expired while listing devices. Grab a fresh cookie and reconnect.'
        }
        if ($list.StatusCode -lt 200 -or $list.StatusCode -ge 300) {
            throw "Connect validation failed: HTTP $($list.StatusCode)"
        }

        $err = $null
        if ($list.Content -is [pscustomobject] -and $list.Content.PSObject.Properties['Error']) {
            $err = $list.Content.Error
        }
        if ($err -eq $true) {
            throw "Connect validation failed: the device list returned an error for school '$IdSchool' / os '$Os'. Check the school slug matches the login you used."
        }

        $count = 0
        if ($list.Content -is [pscustomobject] -and $list.Content.MDMResponse -and $list.Content.MDMResponse.devices) {
            $count = @($list.Content.MDMResponse.devices).Count
        }
        Write-Verbose "Connected to $base as school=$IdSchool os=$Os ($count device(s) on page 1)."
    }

    if ($SaveCookie -and $cookieText) {
        $dir = Split-Path -Parent $defaultCookiePath
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $defaultCookiePath -Value $cookieText.Trim() -Encoding utf8 -NoNewline
        if ($IsLinux -or $IsMacOS) {
            & chmod 600 $defaultCookiePath
        }
        Write-Verbose "Saved cookie to $defaultCookiePath"
    }

    $script:DefaultMosyleFreeSession = $session
    if ($PassThru) { return $session }
}
