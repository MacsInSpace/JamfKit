BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'src' 'JamfSchoolKit' 'JamfSchoolKit.psd1') -Force

    function New-TestSchoolSession {
        [pscustomobject]@{
            PSTypeName      = 'JamfSchoolKit.Session'
            BaseUri         = 'https://school.jamfcloud.com'
            Credential      = [pscredential]::new('1234567890', (ConvertTo-SecureString 'api-key' -AsPlainText -Force))
            ProtocolVersion = 3
            WebSession      = $null
        }
    }
}

Describe 'JamfSchoolKit module' {
    It 'has a valid manifest and exports what it declares' {
        $manifestPath = Join-Path $PSScriptRoot '..' 'src' 'JamfSchoolKit' 'JamfSchoolKit.psd1'
        { Test-ModuleManifest -Path $manifestPath -ErrorAction Stop } | Should -Not -Throw
        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $exported = (Get-Module JamfSchoolKit).ExportedFunctions.Keys | Sort-Object
        $exported | Should -Be ($manifest.FunctionsToExport | Sort-Object)
    }

    It 'has help with a synopsis on every public function' {
        foreach ($functionName in (Get-Module JamfSchoolKit).ExportedFunctions.Keys) {
            (Get-Help $functionName).Synopsis | Should -Not -BeNullOrEmpty -Because "$functionName needs help"
        }
    }
}

Describe 'Request engine' {
    BeforeEach {
        $script:session = New-TestSchoolSession
        Mock -ModuleName JamfSchoolKit Start-Sleep { }
    }

    It 'sends Basic credentials and the protocol version header on every call' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp {
            [pscustomobject]@{ StatusCode = 200; Headers = $null; Content = [pscustomobject]@{ code = 200 } }
        }
        InModuleScope JamfSchoolKit -Parameters @{ s = $script:session } {
            Invoke-JamfSchoolRequest -Session $s -Method GET -Path 'devices' | Out-Null
        }
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp -Times 1 -Exactly -ParameterFilter {
            $Credential.UserName -eq '1234567890' -and
            $Headers['X-Server-Protocol-Version'] -eq '3' -and
            $Uri.AbsoluteUri -eq 'https://school.jamfcloud.com/api/devices'
        }
    }

    It 'honors a per-call protocol version override' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp {
            [pscustomobject]@{ StatusCode = 200; Headers = $null; Content = $null }
        }
        InModuleScope JamfSchoolKit -Parameters @{ s = $script:session } {
            Invoke-JamfSchoolRequest -Session $s -Method GET -Path 'devices' -ProtocolVersion 2 | Out-Null
        }
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp -Times 1 -Exactly -ParameterFilter {
            $Headers['X-Server-Protocol-Version'] -eq '2'
        }
    }

    It 'retries 429 honoring Retry-After' {
        $script:calls = 0
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp {
            $script:calls++
            if ($script:calls -eq 1) {
                return [pscustomobject]@{ StatusCode = 429; Headers = @{ 'Retry-After' = @('2') }; Content = $null }
            }
            [pscustomobject]@{ StatusCode = 200; Headers = $null; Content = 'ok' }
        }
        $result = InModuleScope JamfSchoolKit -Parameters @{ s = $script:session } {
            Invoke-JamfSchoolRequest -Session $s -Method GET -Path 'devices'
        }
        $result | Should -Be 'ok'
        Should -Invoke -ModuleName JamfSchoolKit Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 2 }
    }

    It 'surfaces the API error message on failure' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolHttp {
            [pscustomobject]@{ StatusCode = 404; Headers = $null; Content = [pscustomobject]@{ code = 404; message = 'DeviceNotFound' } }
        }
        {
            InModuleScope JamfSchoolKit -Parameters @{ s = $script:session } {
                Invoke-JamfSchoolRequest -Session $s -Method GET -Path 'devices/NOPE'
            }
        } | Should -Throw '*HTTP 404*DeviceNotFound*'
    }
}

Describe 'Devices' {
    BeforeEach {
        $script:session = New-TestSchoolSession
    }

    It 'lists with filters as string booleans and unwraps the envelope' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; count = 1; devices = @([pscustomobject]@{ UDID = 'u1'; serialNumber = 'S1' }) }
        }
        $devices = Get-JamfSchoolDevice -Session $script:session -SerialNumber S1 -Supervised $true
        @($devices)[0].UDID | Should -Be 'u1'
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'devices' -and $Query['serialnumber'] -eq 'S1' -and $Query['supervised'] -eq 'true'
        }
    }

    It 'gets a device by UDID' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; device = [pscustomobject]@{ UDID = 'u1'; name = 'iPad-01' } }
        }
        (Get-JamfSchoolDevice -Session $script:session -Udid u1).name | Should -Be 'iPad-01'
    }

    It 'sends wipe with the string-boolean activation lock flag' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; message = 'DeviceWipeScheduled' }
        }
        Invoke-JamfSchoolDeviceCommand -Session $script:session -Udid u1 -Command Wipe -ClearActivationLock -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Path -eq 'devices/u1/wipe' -and $Body.clearActivationLock -eq 'true'
        }
    }

    It 'routes ClearActivationLock to its dedicated path and surfaces embedded failures' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 400; message = 'UnlockFailed'; reason = 'Device offline' }
        }
        {
            Invoke-JamfSchoolDeviceCommand -Session $script:session -Udid u1 -Command ClearActivationLock -Confirm:$false
        } | Should -Throw '*UnlockFailed*Device offline*'
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'devices/u1/activationlock/clear'
        }
    }

    It 'makes no API call under -WhatIf' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest { $null }
        Invoke-JamfSchoolDeviceCommand -Session $script:session -Udid u1 -Command Restart -WhatIf
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 0 -Exactly
    }

    It 'assigns and clears the owner via the user-0 convention' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest { [pscustomobject]@{ code = 200; message = 'DeviceSaved' } }
        Set-JamfSchoolDeviceOwner -Session $script:session -Udid u1 -UserId 1234 -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and $Path -eq 'devices/u1/owner' -and $Body.user -eq 1234
        }
        Set-JamfSchoolDeviceOwner -Session $script:session -Udid u1 -Clear -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Body.user -eq 0
        }
    }
}

Describe 'Device groups' {
    BeforeEach {
        $script:session = New-TestSchoolSession
    }

    It 'unwraps the capital-D DeviceGroups list envelope' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; DeviceGroups = @([pscustomobject]@{ id = 12; name = 'Carts' }) }
        }
        (Get-JamfSchoolDeviceGroup -Session $script:session)[0].name | Should -Be 'Carts'
    }

    It 'adds and removes members with the documented groupId/udids payload' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; devicesAdded = 2; devicesRemoved = 1 }
        }
        Set-JamfSchoolDeviceGroupMember -Session $script:session -GroupId 12 -Add u1, u2 -Remove u3 -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'devices/groups/add' -and $Body.groupId -eq 12 -and (@($Body.udids) -join ',') -eq 'u1,u2'
        }
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'devices/groups/remove' -and (@($Body.udids) -join ',') -eq 'u3'
        }
    }
}

Describe 'Users' {
    BeforeEach {
        $script:session = New-TestSchoolSession
    }

    It 'creates a user with memberOf mixing names and ids, then refetches' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            if ($Method -eq 'POST') { return [pscustomobject]@{ code = 200; message = 'UserCreated'; id = 555 } }
            [pscustomobject]@{ code = 200; user = [pscustomobject]@{ id = 555; username = 'jappleseed' } }
        }
        $user = New-JamfSchoolUser -Session $script:session -Username jappleseed `
            -Password (ConvertTo-SecureString 'pw' -AsPlainText -Force) -Email ja@school.org `
            -FirstName Johnny -LastName Appleseed -MemberOf 'Students', 12 -Confirm:$false
        $user.username | Should -Be 'jappleseed'
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Path -eq 'users' -and
            $Body.password -eq 'pw' -and
            @($Body.memberOf)[0] -eq 'Students' -and @($Body.memberOf)[1] -eq 12
        }
    }

    It 'routes password changes to the dedicated endpoint' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest { [pscustomobject]@{ code = 200; message = 'UserDetailsSaved' } }
        Set-JamfSchoolUser -Session $script:session -Id 555 -Email new@school.org `
            -Password (ConvertTo-SecureString 'newpw' -AsPlainText -Force) -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and $Path -eq 'users/555' -and $Body.email -eq 'new@school.org'
        }
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and $Path -eq 'users/555/password' -and $Body.password -eq 'newpw'
        }
    }
}

Describe 'Classes' {
    BeforeEach {
        $script:session = New-TestSchoolSession
    }

    It 'always sends protocol v3 for class endpoints' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            [pscustomobject]@{ code = 200; classes = @() }
        }
        Get-JamfSchoolClass -Session $script:session | Out-Null
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Path -eq 'classes' -and $ProtocolVersion -eq 3
        }
    }

    It 'assigns class users with string IDs' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest { [pscustomobject]@{ code = 200; message = 'ClassSaved' } }
        Set-JamfSchoolClass -Session $script:session -Uuid abc -Students 123, 456 -Teachers 113971 -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'PUT' -and $Path -eq 'classes/abc/users' -and
            @($Body.students)[0] -is [string] -and @($Body.students)[0] -eq '123' -and
            @($Body.teachers)[0] -eq '113971'
        }
    }

    It 'removes class users via the query string' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest { [pscustomobject]@{ code = 200; message = 'ClassUsersDeleted' } }
        Set-JamfSchoolClass -Session $script:session -Uuid abc -RemoveStudents all -Confirm:$false
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Path -eq 'classes/abc/users' -and $Query['students'] -eq 'all'
        }
    }

    It 'creates then refetches by the returned uuid' {
        Mock -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest {
            if ($Method -eq 'POST') { return [pscustomobject]@{ code = 200; message = 'ClassSaved'; uuid = 'new-uuid' } }
            [pscustomobject]@{ code = 200; class = [pscustomobject]@{ uuid = 'new-uuid'; name = 'Year 8 Science' } }
        }
        $class = New-JamfSchoolClass -Session $script:session -Name 'Year 8 Science' -Teachers 113971 -Confirm:$false
        $class.name | Should -Be 'Year 8 Science'
        Should -Invoke -ModuleName JamfSchoolKit Invoke-JamfSchoolRequest -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and $Path -eq 'classes/new-uuid'
        }
    }
}
