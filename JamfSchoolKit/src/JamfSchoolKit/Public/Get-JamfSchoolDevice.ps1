function Get-JamfSchoolDevice {
    <#
    .SYNOPSIS
        Gets devices from Jamf School.
    .DESCRIPTION
        Lists devices with server-side filters, or fetches one by -Udid. Booleans are
        sent as the string form the API expects.
    .PARAMETER Groups
        Filter by device group IDs (comma-joined server-side), e.g. 12,40.
    .PARAMETER OwnerGroups
        Filter by the owner's user group IDs.
    .EXAMPLE
        Get-JamfSchoolDevice
    .EXAMPLE
        Get-JamfSchoolDevice -SerialNumber F9FXH12ABC
    .EXAMPLE
        Get-JamfSchoolDevice -Groups 12 -Supervised $true -IncludeApps
    .EXAMPLE
        Get-JamfSchoolDevice -Udid 1ab2... -IncludeApps
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Udid', ValueFromPipelineByPropertyName)]
        [string] $Udid,

        [Parameter(ParameterSetName = 'List')]
        [string] $SerialNumber,

        [Parameter(ParameterSetName = 'List')]
        [string] $Name,

        [Parameter(ParameterSetName = 'List')]
        [string] $AssetTag,

        [Parameter(ParameterSetName = 'List')]
        [int] $Owner,

        [Parameter(ParameterSetName = 'List')]
        [int[]] $Groups,

        [Parameter(ParameterSetName = 'List')]
        [int[]] $OwnerGroups,

        [Parameter(ParameterSetName = 'List')]
        [string] $Model,

        [Parameter(ParameterSetName = 'List')]
        [string] $LocationId,

        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('manual', 'depPending', 'ac2Pending', 'dep', 'ac2')]
        [string] $EnrollType,

        [Parameter(ParameterSetName = 'List')]
        [bool] $InTrash,

        [Parameter(ParameterSetName = 'List')]
        [bool] $HasOwner,

        [Parameter(ParameterSetName = 'List')]
        [bool] $Managed,

        [Parameter(ParameterSetName = 'List')]
        [bool] $Supervised,

        [switch] $IncludeApps,

        [PSTypeName('JamfSchoolKit.Session')]
        [object] $Session
    )

    begin {
        $resolved = Assert-JamfSchoolSession -Session $Session
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Udid') {
            $query = @{}
            if ($IncludeApps) { $query['includeApps'] = 'true' }
            $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path "devices/$Udid" -Query $query
            return (Select-JamfSchoolResult -Response $response -Property 'device')
        }

        $query = @{}
        if ($SerialNumber) { $query['serialnumber'] = $SerialNumber }
        if ($Name) { $query['name'] = $Name }
        if ($AssetTag) { $query['assettag'] = $AssetTag }
        if ($PSBoundParameters.ContainsKey('Owner')) { $query['owner'] = $Owner }
        if ($null -ne $Groups -and $Groups.Count -gt 0) { $query['groups'] = ($Groups -join ',') }
        if ($null -ne $OwnerGroups -and $OwnerGroups.Count -gt 0) { $query['ownergroups'] = ($OwnerGroups -join ',') }
        if ($Model) { $query['model'] = $Model }
        if ($LocationId) { $query['location'] = $LocationId }
        if ($EnrollType) { $query['enrollType'] = $EnrollType }
        foreach ($boolParam in 'InTrash', 'HasOwner', 'Managed', 'Supervised') {
            if ($PSBoundParameters.ContainsKey($boolParam)) {
                $query[$boolParam.Substring(0, 1).ToLowerInvariant() + $boolParam.Substring(1)] =
                    ([bool]$PSBoundParameters[$boolParam]).ToString().ToLowerInvariant()
            }
        }
        if ($IncludeApps) { $query['includeApps'] = 'true' }

        $response = Invoke-JamfSchoolRequest -Session $resolved -Method GET -Path 'devices' -Query $query
        Select-JamfSchoolResult -Response $response -Property 'devices'
    }
}
