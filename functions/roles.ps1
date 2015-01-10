function Add-DSCRolemap
{
    <#
    .SYNOPSIS
    Adds a rolemap to the internal _rolemap array

    .EXAMPLE
    Add-DSCRolemap 'foo' @('foo/bar','foo/baz')

    #>
    #todo: Add-DSCRoleMap needs to have the parameters more rigidly defined
    Param(
        $roleMapName,
        $roles
    )
    $configuration['_rolemap'][$roleMapName] = $roles
}
function Expand-DSCActualRoles
{
    <#
    .SYNOPSIS
    Scans the roles specified in $configuration.roles and expands any rolemaps.
    #>
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
    <#
    .SYNOPSIS
    Checks the $configuration._rolesincluded array for the specified role and throws an exception if not present.

    .PARAMETER name
    The name of the role to require

    .EXAMPLE
    Require-DSCRole -name 'foo/bar'

    #>
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
    <#
    .SYNOPSIS
    Imports DSC actual roles, executing the init section and optionally the DSC configuration block.

    .PARAMETER actualRoles
    An array of roles to import

    .PARAMETER invokeConfiguration
    IF specified, the DSC configuration is invoked. This is usually done by New-DSCConfiguration

    .EXAMPLE
    Import-DSCActualRoles -actualRoles @('foo/bar','foo/baz')

    #>
    param(
        [Parameter(
            Mandatory=$true
        )][array]$actualRoles,
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