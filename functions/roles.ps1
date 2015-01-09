function Add-DSCRolemap
{
    Param(
        $roleMapName,
        $roles
    )
    $configuration['_rolemap'][$roleMapName] = $roles
}
function Expand-DSCActualRoles
{
    $actual_roles = @()
    $rolemap = $configuration['_rolemap']
    $configuration.roles | % {
        if ($rolemap.ContainsKey($_)) {
            $rolemap[$_] | % { $actual_roles = $actual_roles + $_ }
        } else {
            $actual_roles = $actual_roles + $_
        }
    }
    return $actual_roles
}
function Require-DSCRole {
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String[]]$name
    ) 
    if ($configuration['_rolesincluded'] -notcontains $name) {
        Write-Error "`nRequired role $name not loaded."
        throw { "Required role not loaded." }
    }
}
function Import-DSCActualRoles
{
    param(
        [Parameter(
            Mandatory=$true
        )]$actualRoles,
        [switch]$invokeConfiguration
    )
    $actualRoles | % {
        #Write-Output "Start $_"
        if (!($_.Contains("/"))) { throw "Role $($_) does not contain a namespace." }
        $role = $_.Split("/")
        $roleNamespace = $role[0]
        $roleName = $role[1]
        $roleFullyQualified = $_.Replace("/","_")

        $source = $configuration['_sources'][$role[0]]
        $rolefile = "$($source['path'])\roles\$($role[1]).ps1"
        . "$($source['path'])\roles\$($role[1]).ps1"
        #Write-Output "Finish $_"
        #$role = $_.Replace("/","_")
        #Write-Output "invoking $role"
        if ($invokeConfiguration) { Invoke-Expression "Role_$roleFullyQualified $roleFullyQualified {}" }
    }

}