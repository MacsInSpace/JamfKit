BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'src' 'JamfProKit' 'JamfProKit.psd1') -Force
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
}

Describe 'EA_n CSV column support' {
    BeforeEach {
        $script:session = New-TestJamfSession
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
    }

    It 'reads EA_ columns straight off a MUT computer CSV row' {
        $mutRow = [pscustomobject]@{
            'Computer Serial' = 'C02EA0001'
            'Asset Tag'       = 'A-1'
            'EA_2'            = 'Building A'
            'EA_7'            = 'CLEAR!'
            'EA_9'            = ''
        }
        $mutRow | Update-JamfComputer -Session $script:session -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Body.OuterXml -like '*<extension_attribute><id>2</id><value>Building A</value></extension_attribute>*' -and
            ($Body.OuterXml -like '*<id>7</id><value></value>*' -or $Body.OuterXml -like '*<id>7</id><value />*') -and
            $Body.OuterXml -notlike '*<id>9</id>*'
        }
    }

    It 'lets an explicit -ExtensionAttribute override a CSV EA_ column' {
        $mutRow = [pscustomobject]@{ 'Computer Serial' = 'C02EA0002'; 'EA_2' = 'from-csv' }
        $mutRow | Update-JamfComputer -Session $script:session -ExtensionAttribute @{ 2 = 'explicit-wins' } -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Body.OuterXml -like '*<id>2</id><value>explicit-wins</value>*'
        }
    }
}

Describe 'Update-JamfMobileDevice' {
    BeforeEach {
        $script:session = New-TestJamfSession
    }

    It 'binds a MUT mobile template row and PUTs Classic XML' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
        $mutRow = [pscustomobject]@{
            'Mobile Device Serial'         = 'F9FXH12ABC'
            'Asset Tag'                    = 'IPAD-01'
            'Room'                         = 'Lab 2'
            'Airplay Password (tvOS Only)' = ''
            'Site (ID or Name)'            = 'CLEAR!'
        }
        $result = $mutRow | Update-JamfMobileDevice -Session $script:session -Confirm:$false
        $result.Status | Should -Be 'Updated'
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and
            $Path -eq 'JSSResource/mobiledevices/serialnumber/F9FXH12ABC' -and
            $Body.OuterXml -like '*<asset_tag>IPAD-01</asset_tag>*' -and
            $Body.OuterXml -like '*<room>Lab 2</room>*' -and
            $Body.OuterXml -like '*<site><id>-1</id></site>*' -and
            $Body.OuterXml -notlike '*airplay*'
        }
    }

    It 'chains the enforce-name PATCH using the id parsed from the Classic response' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'PUT') { return [xml]'<mobile_device><id>77</id></mobile_device>' }
            $null
        }
        Update-JamfMobileDevice -Session $script:session -SerialNumber 'F9FXH12ABC' `
            -AssetTag 'IPAD-01' -DisplayName 'Cart-01' -EnforceName 'TRUE' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PATCH' -and
            $Path -eq 'api/v2/mobile-devices/77' -and
            $Body.name -eq 'Cart-01' -and
            $Body.enforceName -eq $true
        }
    }

    It 'resolves the device id by serial for a name-only change' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ totalCount = 1; results = @([pscustomobject]@{ id = '31'; serialNumber = 'F9FXH12ABC' }) }
            }
            $null
        }
        Update-JamfMobileDevice -Session $script:session -SerialNumber 'F9FXH12ABC' `
            -DisplayName 'Cart-02' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 0 -Exactly -ParameterFilter { $Method -eq 'PUT' }
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PATCH' -and $Path -eq 'api/v2/mobile-devices/31' -and $Body.name -eq 'Cart-02'
        }
    }

    It 'fails the row when the serial cannot be resolved for a name change' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ totalCount = 0; results = @() } }
            $null
        }
        $result = Update-JamfMobileDevice -Session $script:session -SerialNumber 'NOPE' `
            -DisplayName 'X' -Confirm:$false -ErrorAction SilentlyContinue
        $result.Status | Should -Be 'Failed'
        $result.Error | Should -BeLike '*Could not resolve*'
    }

    It 'warns and skips an invalid EnforceName value' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
        Update-JamfMobileDevice -Session $script:session -SerialNumber 'F9FXH12ABC' -AssetTag 'A' `
            -EnforceName 'maybe' -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null
        $warnings | Should -Not -BeNullOrEmpty
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 0 -Exactly -ParameterFilter { $Method -eq 'PATCH' }
    }

    It 'makes no API call under -WhatIf' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
        Update-JamfMobileDevice -Session $script:session -SerialNumber 'F9FXH12ABC' -AssetTag 'A' -WhatIf | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 0 -Exactly
    }
}

Describe 'Update-JamfUser' {
    BeforeEach {
        $script:session = New-TestJamfSession
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
    }

    It 'binds a MUT user template row: rename, dual email, LDAP clear, site, Managed Apple ID' {
        $mutRow = [pscustomobject]@{
            'Current Username' = 'jappleseed'
            'New Username'     = 'j.appleseed'
            'Full Name'        = 'Johnny Appleseed'
            'Email Address'    = 'ja@acme.com'
            'LDAP Server ID'   = 'CLEAR!'
            'Site (ID or Name)' = 'Head Office'
            'Managed Apple ID (Requires Jamf Pro 10.15+)' = 'ja@appleid.acme.com'
        }
        $result = $mutRow | Update-JamfUser -Session $script:session -Confirm:$false
        $result.Status | Should -Be 'Updated'
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and
            $Path -eq 'JSSResource/users/name/jappleseed' -and
            $Body.OuterXml -like '*<name>j.appleseed</name>*' -and
            $Body.OuterXml -like '*<full_name>Johnny Appleseed</full_name>*' -and
            $Body.OuterXml -like '*<email>ja@acme.com</email>*' -and
            $Body.OuterXml -like '*<email_address>ja@acme.com</email_address>*' -and
            $Body.OuterXml -like '*<ldap_server><id>-1</id></ldap_server>*' -and
            $Body.OuterXml -like '*<sites><site><name>Head Office</name></site></sites>*' -and
            $Body.OuterXml -like '*<managed_apple_id>ja@appleid.acme.com</managed_apple_id>*'
        }
    }

    It 'treats an all-digit username as a Jamf ID by default' {
        Update-JamfUser -Session $script:session -Username '4521' -Position 'Teacher' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'JSSResource/users/id/4521'
        }
    }

    It 'treats an all-digit username as a name with -NumericIdentifiersAreNames' {
        Update-JamfUser -Session $script:session -Username '4521' -NumericIdentifiersAreNames `
            -Position 'Student' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'JSSResource/users/name/4521'
        }
    }

    It 'skips rows with no changes' {
        Update-JamfUser -Session $script:session -Username 'jappleseed' -FullName '' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 0 -Exactly
    }
}

Describe 'Set-JamfPrestageScope' {
    BeforeEach {
        $script:session = New-TestJamfSession
    }

    It 'fetches the versionLock then POSTs additions with it' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ prestageId = '3'; versionLock = 7; assignments = @() } }
            [pscustomobject]@{ ok = $true }
        }
        Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Add 'C02AAA', 'C02BBB' -Confirm:$false | Out-Null
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Path -eq 'api/v2/computer-prestages/3/scope' -and
            $Body.versionLock -eq 7 -and
            (@($Body.serialNumbers) -join ',') -eq 'C02AAA,C02BBB'
        }
    }

    It 'removes via delete-multiple and uses mobile endpoints for -Type MobileDevice' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ versionLock = 2 } }
            $null
        }
        Set-JamfPrestageScope -Session $script:session -PrestageId 5 -Type MobileDevice -Remove 'F9F001' -Confirm:$false
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Path -eq 'api/v2/mobile-device-prestages/5/scope/delete-multiple' -and
            $Body.versionLock -eq 2
        }
    }

    It 'replaces the scope with PUT' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ versionLock = 4 } }
            $null
        }
        Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Replace 'C02NEW' -Confirm:$false
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and $Path -eq 'api/v2/computer-prestages/3/scope' -and $Body.versionLock -eq 4
        }
    }

    It 'refetches the lock and retries on a version conflict' {
        $script:lock = 10
        $script:writeAttempts = 0
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') {
                $script:lock++
                return [pscustomobject]@{ versionLock = $script:lock }
            }
            $script:writeAttempts++
            if ($script:writeAttempts -eq 1) {
                throw 'Jamf API request failed: POST ... returned HTTP 409. Optimistic lock failure.'
            }
            $null
        }
        Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Add 'C02AAA' -Confirm:$false
        $script:writeAttempts | Should -Be 2
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Body.versionLock -eq 12
        }
    }

    It 'gives up after MaxConflictRetries' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ versionLock = 1 } }
            throw 'Jamf API request failed: POST ... returned HTTP 409.'
        }
        { Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Add 'C02AAA' `
                -MaxConflictRetries 1 -Confirm:$false } | Should -Throw '*HTTP 409*'
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 2 -Exactly -ParameterFilter { $Method -eq 'POST' }
    }

    It 'does not retry non-conflict failures' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest {
            if ($Method -eq 'GET') { return [pscustomobject]@{ versionLock = 1 } }
            throw 'Jamf API request failed: POST ... returned HTTP 400. INVALID_FIELD: bad serial.'
        }
        { Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Add 'BAD' -Confirm:$false } |
            Should -Throw '*HTTP 400*'
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 1 -Exactly -ParameterFilter { $Method -eq 'POST' }
    }

    It 'makes no API call under -WhatIf' {
        Mock -ModuleName JamfProKit Invoke-JamfRequest { $null }
        Set-JamfPrestageScope -Session $script:session -PrestageId 3 -Add 'C02AAA' -WhatIf
        Should -Invoke -ModuleName JamfProKit Invoke-JamfRequest -Times 0 -Exactly
    }
}
