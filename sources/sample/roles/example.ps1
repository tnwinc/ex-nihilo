<#
 # The example role file
 # Initialization should follow this order:
 # 1. Required roles (dependencies)
 # 2. Default configs
 # 3. Configs from hypervisor
 # 4. Required configs
 # 5. Any special initialization code
 # 6. Add role to rolesIncluded (initialization complete)
 # 7. DSC configuration block
 #>

<#
 # A role is required to push it's name onto the array $configuration['_rolesincluded']. Use
 # Require-DSCRole to throw an exception if a dependency has not been loaded.
 #>
Require-DSCRole "role_name"


<#
 # Configuration defaults can be established by setting them with the global configuration
 # object.
 #>
Set-DSCConfiguration 'example_key' "value"

<#
 # Configuration directives can be passed in through the hypervisor. Use
 # Get-DSCConfigFromVMWare "keyname" to check for a setting. The property,
 # if set, will be automatically loaded into the configuration object.
 #>
Get-DSCConfigFromVMWare "example_key"

<#
 # Required configs will throw an exception if not defined in the global config object.
 #>
Require-DSCConfiguration "example_key"

<#
 # Do any additional initialization code. Any valid powershell can be used
 #>
Write-Host "Example has no special initialization code"

<#
 # The role name should be added to the roles included array so that it's registered
 # if other roles depend on it.
 #>
$configuration['_rolesincluded'] += "example"

<#
 # The DSC configuration block should go last. It's a standard DSC config block.
 #>
Configuration Role_namespace_example {

}