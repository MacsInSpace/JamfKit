BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'src' 'MosyleFreeKit' 'MosyleFreeKit.psd1') -Force

    function New-TestMosyleFreeSession {
        $ws = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $c = [System.Net.Cookie]::new('PHPSESSID', 'test-session', '/', 'myschool.mosyle.com')
        $ws.Cookies.Add($c)
        [pscustomobject]@{
            PSTypeName      = 'MosyleFreeKit.Session'
            BaseUri         = 'https://myschool.mosyle.com'
            IdSchool        = 'yourschool'
            Os              = 'ios'
            WebSession       = $ws
            AdminCredential = $null
            ConnectedAt     = [DateTimeOffset]::UtcNow
        }
    }
}

Describe 'MosyleFreeKit module' {
    It 'has a valid manifest and exports what it declares' {
        $manifestPath = Join-Path $PSScriptRoot '..' 'src' 'MosyleFreeKit' 'MosyleFreeKit.psd1'
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        (Get-Module MosyleFreeKit).ExportedFunctions.Keys | Sort-Object |
            Should -Be ($manifest.FunctionsToExport | Sort-Object)
    }

    It 'has help with a synopsis on every public function' {
        foreach ($functionName in (Get-Module MosyleFreeKit).ExportedFunctions.Keys) {
            (Get-Help $functionName).Synopsis | Should -Not -BeNullOrEmpty -Because "$functionName needs help"
        }
    }
}

Describe 'Form encoding' {
    It 'encodes hashtables as application/x-www-form-urlencoded' {
        InModuleScope MosyleFreeKit {
            $body = ConvertTo-MosyleFreeFormBody -Form @{
                mapping    = 'BulkOperationsController'
                operation  = 'bulk_restart'
                deviceudid = 'abc 123'
            }
            $body | Should -Match 'mapping=BulkOperationsController'
            $body | Should -Match 'operation=bulk_restart'
            $body | Should -Match 'deviceudid=abc%20123'
        }
    }
}

Describe 'Session assert' {
    It 'throws when not connected' {
        InModuleScope MosyleFreeKit {
            $script:DefaultMosyleFreeSession = $null
            { Assert-MosyleFreeSession } | Should -Throw '*Connect-MosyleFree*'
        }
    }

    It 'accepts a typed session' {
        $s = New-TestMosyleFreeSession
        InModuleScope MosyleFreeKit -Parameters @{ s = $s } {
            (Assert-MosyleFreeSession -Session $s).IdSchool | Should -Be 'yourschool'
        }
    }
}

Describe 'Get-MosyleFreeDevice' {
    It 'unwraps MDMResponse.devices and adds UDID alias' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{
                    Error       = $false
                    MDMResponse = [pscustomobject]@{
                        devices = @(
                            [pscustomobject]@{
                                deviceudid    = 'udid-1'
                                serial_number = 'SN1'
                                device_name   = 'iPad'
                            }
                        )
                    }
                }
                RawContent = '{"Error":false,"MDMResponse":{"devices":[{"deviceudid":"udid-1"}]}}'
            }
        }

        $devices = Get-MosyleFreeDevice -Session $s -Os ios -Page 1
        @($devices).Count | Should -Be 1
        $devices[0].UDID | Should -Be 'udid-1'
        $devices[0].serial_number | Should -Be 'SN1'
    }

    It 'looks up -SerialNumber with term/search fields' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{
                    Error       = $false
                    MDMResponse = [pscustomobject]@{
                        devices = @(
                            [pscustomobject]@{
                                deviceudid    = 'udid-sn'
                                serial_number = 'ABCD1234EFGH'
                                device_name   = 'ABCD1234EFGH'
                            }
                        )
                    }
                }
                RawContent = '{}'
            }
        }

        $devices = Get-MosyleFreeDevice -Session $s -Os ios -SerialNumber 'ABCD1234EFGH'
        @($devices).Count | Should -Be 1
        $devices[0].UDID | Should -Be 'udid-sn'

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/devices_list_ajax.php' -and
            $Form.term -eq 'ABCD1234EFGH' -and
            $Form.search -eq 'ABCD1234EFGH' -and
            $Form.last_search -eq 'serial_number'
        }
    }

    It 'returns empty under StrictMode when devices:[] (mac/tvos empty school)' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{
                    Error       = $false
                    MDMResponse = [pscustomobject]@{
                        devices = @()
                    }
                }
                RawContent = '{"Error":false,"MDMResponse":{"devices":[]}}'
            }
        }

        Set-StrictMode -Version Latest
        { Get-MosyleFreeDevice -Session $s -Os mac -Page 1 } | Should -Not -Throw
        $devices = @(Get-MosyleFreeDevice -Session $s -Os mac -Page 1)
        $devices.Count | Should -Be 0
    }
}

Describe 'ConvertFrom-MosyleFreeDeviceCommandsHtml' {
    It 'parses pending Lock and Shutdown rows' {
        InModuleScope MosyleFreeKit {
            $html = @'
<div>Before resending</div>
Pending Command Shutdown Device System-Scope Shutdown Device Date created: 12:59 AM - 19/07/26 Date last connection: 07:36 PM - 11/08/21
Pending Command Turn Off the Screen System-Scope Turn Off the Screen Date created: 12:53 AM - 19/07/26 Date last connection: 07:36 PM - 11/08/21
<script>$("#clear_pending").show();</script>
'@
            $rows = ConvertFrom-MosyleFreeDeviceCommandsHtml -Html $html -Device 'udid-1' -SerialNumber 'SN1'
            @($rows).Count | Should -Be 2
            $rows.Label | Should -Contain 'Shutdown Device'
            $rows.Label | Should -Contain 'Turn Off the Screen'
            $rows[0].Status | Should -Be 'Pending'
            $rows[0].Device | Should -Be 'udid-1'
        }
    }

    It 'returns empty for no pending message' {
        InModuleScope MosyleFreeKit {
            $rows = ConvertFrom-MosyleFreeDeviceCommandsHtml -Html 'There are no pending or failed commands for this device'
            @($rows).Count | Should -Be 0
        }
    }
}

Describe 'Get-MosyleFreeDeviceCommand' {
    It 'posts device_commands.php and returns parsed rows' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = 'html'
                RawContent = 'Pending Command Turn Off the Screen System-Scope Turn Off the Screen Date created: 01:00 AM - 19/07/26 Date last connection: 07:36 PM - 11/08/21'
            }
        }

        $rows = Get-MosyleFreeDeviceCommand -Device 'udid-1' -SerialNumber 'SN1' -Session $s
        @($rows).Count | Should -Be 1
        $rows[0].Label | Should -Be 'Turn Off the Screen'

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Uri -like '*/deviceinfo/device_commands.php' -and
            $Form.deviceudid -eq 'udid-1' -and
            $Form.action -eq 'COMMANDS'
        }
    }
}

Describe 'Invoke-MosyleFreeDeviceCommand' {
    BeforeEach {
        $script:session = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
    }

    It 'posts bulk_restart per device through mapping.php' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        $results = Invoke-MosyleFreeDeviceCommand -Command Restart -Device 'udid-a', 'udid-b' `
            -Session $script:session -Confirm:$false -DelayMs 0
        @($results).Count | Should -Be 2
        $results | ForEach-Object { $_.Ok | Should -BeTrue }

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 2 -Exactly -ParameterFilter {
            $Uri -like '*/Controller/mapping.php' -and
            $Form.operation -eq 'bulk_restart' -and
            $Form.mapping -eq 'BulkOperationsController'
        }
    }

    It 'posts lock_device with LockMessage' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command Lock -Device 'udid-1' -LockMessage 'IT' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'lock_device' -and $Form.LockMessage -eq 'IT'
        }
    }

    It 'posts device_clear_commands for ClearPendingCommands' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command ClearPendingCommands -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.mapping -eq 'CommandController' -and
            $Form.operation -eq 'device_clear_commands' -and
            $Form.command_status -eq 'pending'
        }
    }

    It 'supports -WhatIf without calling HTTP' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp { throw 'should not call HTTP' }
        $r = Invoke-MosyleFreeDeviceCommand -Command Restart -Device 'udid-1' `
            -Session $script:session -WhatIf
        $r.WhatIf | Should -BeTrue
        $r.Ok | Should -BeTrue
    }

    It 'posts wipe_device and refuses empty udid' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        $empty = Invoke-MosyleFreeDeviceCommand -Command Wipe -Device '   ' `
            -Session $script:session -Confirm:$false -DelayMs 0
        $empty.Ok | Should -BeFalse
        $empty.Error | Should -Match 'Empty device'

        Invoke-MosyleFreeDeviceCommand -Command Wipe -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'wipe_device'
        }
    }

    It 'posts change_to_limbo for Unassign' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command Unassign -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'change_to_limbo'
        }
    }

    It 'requires message for EnableActivationLock' {
        {
            Invoke-MosyleFreeDeviceCommand -Command EnableActivationLock -Device 'udid-1' `
                -Session $script:session -Confirm:$false
        } | Should -Throw '*Message*'
    }

    It 'posts bulk_enable_activation_lock with lost_message' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command EnableActivationLock -Device 'udid-1' `
            -Message 'School device' -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'bulk_enable_activation_lock' -and $Form.lost_message -eq 'School device'
        }
    }

    It 'sets Queued from device Commands tab when -Verify' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            param($Uri, $Form)
            if ($Uri -like '*/device_commands.php') {
                return [pscustomobject]@{
                    StatusCode = 200
                    Headers    = $null
                    Content    = 'html'
                    RawContent = 'Pending Command Turn Off the Screen System-Scope Turn Off the Screen Date created: 01:06 AM - 19/07/26 Date last connection: 07:36 PM - 11/08/21'
                }
            }
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Mock -ModuleName MosyleFreeKit Start-Sleep { }

        $r = Invoke-MosyleFreeDeviceCommand -Command Lock -Device 'udid-1' -SerialNumber 'SN1' `
            -LockMessage 'probe' -Session $script:session -Confirm:$false -DelayMs 0 `
            -Verify -VerifySettleMs 0 -VerifyAttempts 1
        $r.Ok | Should -BeTrue
        $r.Queued | Should -BeTrue
    }

    It 'sets Queued false when -Verify and Restart did not enqueue' {
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            param($Uri, $Form)
            if ($Uri -like '*/device_commands.php') {
                return [pscustomobject]@{
                    StatusCode = 200
                    Headers    = $null
                    Content    = 'html'
                    RawContent = 'There are no pending or failed commands for this device'
                }
            }
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        $r = Invoke-MosyleFreeDeviceCommand -Command Restart -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 `
            -Verify -VerifySettleMs 0 -VerifyAttempts 1
        $r.Ok | Should -BeTrue
        $r.Queued | Should -BeFalse
    }

    It 'retries -Verify until Restart OS appears' {
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        $script:cmdHits = 0
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            param($Uri, $Form)
            if ($Uri -like '*/device_commands.php') {
                $script:cmdHits++
                $html = if ($script:cmdHits -ge 2) {
                    'Pending Command Restart OS System-Scope Restart OS'
                } else {
                    'There are no pending or failed commands for this device'
                }
                return [pscustomobject]@{
                    StatusCode = 200
                    Headers    = $null
                    Content    = 'html'
                    RawContent = $html
                }
            }
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        $r = Invoke-MosyleFreeDeviceCommand -Command Restart -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 `
            -Verify -VerifySettleMs 0 -VerifyAttempts 3
        $r.Queued | Should -BeTrue
        $script:cmdHits | Should -BeGreaterOrEqual 2
    }

    It 'posts bulk_send_push for SendPush' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command SendPush -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'bulk_send_push'
        }
    }

    It 'posts update_info for UpdateInfo' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeDeviceCommand -Command UpdateInfo -Device 'udid-1' `
            -Session $script:session -Confirm:$false -DelayMs 0 | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'update_info'
        }
    }
}

Describe 'Invoke-MosyleFreeLostMode' {
    It 'posts ios_enable_lostmode with message/phone/footnote' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Invoke-MosyleFreeLostMode -Action Enable -Device 'udid-1' -Message 'Lost' `
            -PhoneNumber '03 1111 2222' -Footnote 'IT' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'ios_enable_lostmode' -and
            $Form.message -eq 'Lost' -and
            $Form.phone -eq '03 1111 2222' -and
            $Form.footnote -eq 'IT'
        }
    }
}

Describe 'Set-MosyleFreeDeviceName / Tag / Account' {
    It 'posts bullk_change_devicesname (Mosyle spelling)' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Set-MosyleFreeDeviceName -Device 'udid-1' -Name 'Lab iPad' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'bullk_change_devicesname' -and $Form.newname -eq 'Lab iPad'
        }
    }

    It 'posts devices_bulk_add_tag' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Set-MosyleFreeDeviceTag -Device 'udid-1' -Tag 'Loaner' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'devices_bulk_add_tag' -and $Form.tag_name -eq 'Loaner'
        }
    }

    It 'posts devices_bulk_remove_tag' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Remove-MosyleFreeDeviceTag -Device 'udid-1' -Tag 'Loaner' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.operation -eq 'devices_bulk_remove_tag' -and $Form.tag_name -eq 'Loaner'
        }
    }

    It 'posts change_device_account via DeviceInfoController' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Set-MosyleFreeDeviceAccount -Device 'udid-1' -AccountId '99' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.mapping -eq 'DeviceInfoController' -and
            $Form.operation -eq 'change_device_account' -and
            $Form.newAccount -eq '99'
        }
    }

    It 'posts change_to_sharedenroll for Add Shared Device Group' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Add-MosyleFreeDeviceSharedGroup -Device 'udid-1' -GroupId '2' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.mapping -eq 'DeviceInfoController' -and
            $Form.operation -eq 'change_to_sharedenroll' -and
            $Form.idcart -eq '[2]'
        }
    }

    It 'posts change_to_limbo for Remove Shared Device Group' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Start-Sleep { }
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Remove-MosyleFreeDeviceSharedGroup -Device 'udid-1' -Session $s -Confirm:$false -DelayMs 0 |
            Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.mapping -eq 'DeviceInfoController' -and
            $Form.operation -eq 'change_to_limbo'
        }
    }
}

Describe 'Shared Device Group inventory' {
    It 'parses carts_list HTML for id/name/count' {
        InModuleScope MosyleFreeKit {
            $html = @'
<li id="group_1" class="x"><div class="count-elements mt-5">0 <span>devices</span></div>
<div class="title"><img class="icon" src="x.svg" />Staff Devices</div></li>
<li id="group_2" class="x"><div class="count-elements mt-5">1 <span>devices</span></div>
<div class="title"><img class="icon" src="x.svg" />Student Devices</div></li>
'@
            $g = @(ConvertFrom-MosyleFreeSharedGroupsHtml -Html $html)
            $g.Count | Should -Be 2
            $g[0].GroupId | Should -Be '1'
            $g[0].Name | Should -Be 'Staff Devices'
            $g[0].DeviceCount | Should -Be 0
            $g[1].Name | Should -Be 'Student Devices'
            $g[1].DeviceCount | Should -Be 1
        }
    }

    It 'posts delete_cart when removing a Shared Device Group object' {
        $s = New-TestMosyleFreeSession
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Headers    = $null
                Content    = [pscustomobject]@{ status = 'OK' }
                RawContent = '{"status":"OK"}'
            }
        }

        Remove-MosyleFreeSharedDeviceGroup -GroupId '9' -Session $s -Confirm:$false | Out-Null

        Should -Invoke -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp -Times 1 -Exactly -ParameterFilter {
            $Form.mapping -eq 'HierarchyController' -and
            $Form.operation -eq 'delete_cart' -and
            $Form.idcart -eq '9'
        }
    }
}

Describe 'Login page detection' {
    It 'detects Enter your email' {
        InModuleScope MosyleFreeKit {
            Test-MosyleFreeLoginPage -RawContent '<input placeholder="Enter your email">' | Should -BeTrue
        }
    }

    It 'accepts normal JSON' {
        InModuleScope MosyleFreeKit {
            Test-MosyleFreeLoginPage -RawContent '{"status":"OK"}' | Should -BeFalse
        }
    }
}

Describe 'Cookie input parsing' {
    It 'parses a bare PHPSESSID pair' {
        InModuleScope MosyleFreeKit {
            $r = ConvertFrom-MosyleFreeCookieInput -InputText 'PHPSESSID=abc123'
            $r.Cookies['PHPSESSID'] | Should -Be 'abc123'
            $r.IdSchool | Should -BeNullOrEmpty
        }
    }

    It 'parses a Cookie header with the prefix and several pairs' {
        InModuleScope MosyleFreeKit {
            $r = ConvertFrom-MosyleFreeCookieInput -InputText 'Cookie: PHPSESSID=abc123; credentials=eyJhbGciOi.test'
            $r.Cookies['PHPSESSID'] | Should -Be 'abc123'
            $r.Cookies['credentials'] | Should -Be 'eyJhbGciOi.test'
        }
    }

    It 'parses a Copy-as-cURL blob and recovers the school slug' {
        InModuleScope MosyleFreeKit {
            $curl = @"
curl 'https://myschool.mosyle.com/Controller/mapping.php' \
  -H 'accept: */*' \
  -H 'cookie: PHPSESSID=sess987; credentials=eyJ0eXAiOi.demo' \
  --data-raw 'mapping=BulkOperationsController&usertab_current_idschool=demoschool&page=1'
"@
            $r = ConvertFrom-MosyleFreeCookieInput -InputText $curl
            $r.Cookies['PHPSESSID'] | Should -Be 'sess987'
            $r.Cookies['credentials'] | Should -Be 'eyJ0eXAiOi.demo'
            $r.IdSchool | Should -Be 'demoschool'
        }
    }

    It 'parses the -b form of a cURL cookie argument' {
        InModuleScope MosyleFreeKit {
            $r = ConvertFrom-MosyleFreeCookieInput -InputText "curl 'https://myschool.mosyle.com/' -b 'PHPSESSID=viaB'"
            $r.Cookies['PHPSESSID'] | Should -Be 'viaB'
        }
    }

    It 'parses tab-separated DevTools cookie rows' {
        InModuleScope MosyleFreeKit {
            $table = "PHPSESSID`tabc123`tmyschool.mosyle.com`t/`ncredentials`teyJab.cd`t.mosyle.com`t/"
            $r = ConvertFrom-MosyleFreeCookieInput -InputText $table
            $r.Cookies['PHPSESSID'] | Should -Be 'abc123'
            $r.Cookies['credentials'] | Should -Be 'eyJab.cd'
        }
    }

    It 'parses JSON from a cookie-export extension' {
        InModuleScope MosyleFreeKit {
            $json = '[{"name":"PHPSESSID","value":"fromJson"},{"name":"credentials","value":"eyJx.y"}]'
            $r = ConvertFrom-MosyleFreeCookieInput -InputText $json
            $r.Cookies['PHPSESSID'] | Should -Be 'fromJson'
            $r.Cookies['credentials'] | Should -Be 'eyJx.y'
        }
    }

    It 'throws a helpful error on unusable input' {
        InModuleScope MosyleFreeKit {
            { ConvertFrom-MosyleFreeCookieInput -InputText 'no cookies here' } |
                Should -Throw '*Copy as cURL*'
        }
    }

    It 'throws on empty input' {
        InModuleScope MosyleFreeKit {
            { ConvertFrom-MosyleFreeCookieInput -InputText '   ' } | Should -Throw '*Nothing to parse*'
        }
    }
}

Describe 'School slug detection' {
    It 'reads usertab_current_idschool out of the landing page' {
        InModuleScope MosyleFreeKit {
            $html = '<input type="hidden" name="usertab_current_idschool" id="usertab_current_idschool" value="demoschool"/>'
            Get-MosyleFreeSchoolSlug -Html $html | Should -Be 'demoschool'
        }
    }

    It 'returns null when the page carries no slug' {
        InModuleScope MosyleFreeKit {
            Get-MosyleFreeSchoolSlug -Html '<html><body>Enter your email</body></html>' | Should -BeNullOrEmpty
        }
    }

    It 'returns null for empty input' {
        InModuleScope MosyleFreeKit {
            Get-MosyleFreeSchoolSlug -Html '' | Should -BeNullOrEmpty
        }
    }
}

Describe 'Connect-MosyleFree' {
    It 'detects the school from the signed-in page when IdSchool is omitted' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            if ($Method -eq 'GET') {
                return [pscustomobject]@{
                    StatusCode = 200
                    Content    = $null
                    RawContent = '<input name="usertab_current_idschool" value="autodetected"/>'
                }
            }
            [pscustomobject]@{
                StatusCode = 200
                RawContent = '{"Error":false}'
                Content    = [pscustomobject]@{
                    Error       = $false
                    MDMResponse = [pscustomobject]@{ devices = @() }
                }
            }
        }
        $s = Connect-MosyleFree -Cookie 'PHPSESSID=abc123' -PassThru
        $s.IdSchool | Should -Be 'autodetected'
    }

    It 'prefers an explicit IdSchool over detection' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            if ($Method -eq 'GET') {
                return [pscustomobject]@{
                    StatusCode = 200
                    Content    = $null
                    RawContent = '<input name="usertab_current_idschool" value="autodetected"/>'
                }
            }
            [pscustomobject]@{
                StatusCode = 200
                RawContent = '{"Error":false}'
                Content    = [pscustomobject]@{
                    Error       = $false
                    MDMResponse = [pscustomobject]@{ devices = @() }
                }
            }
        }
        $s = Connect-MosyleFree -IdSchool 'explicit' -Cookie 'PHPSESSID=abc123' -PassThru
        $s.IdSchool | Should -Be 'explicit'
    }

    It 'reports a rejected cookie as a login page rather than a vague failure' {
        Mock -ModuleName MosyleFreeKit Invoke-MosyleFreeHttp {
            [pscustomobject]@{
                StatusCode = 200
                Content    = $null
                RawContent = '<html>Enter your email</html>'
            }
        }
        { Connect-MosyleFree -Cookie 'PHPSESSID=stale' } | Should -Throw '*login page*'
    }
}
