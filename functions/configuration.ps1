function Initialize-DSCConfiguration
{
    <#
    .SYNOPSIS
    Initialize the global configuration object, and import seed data.

    .DESCRIPTION
    The configuration data is stored in a global object $configuration. This function will: initialize the object,
    destroying any existing data; setup mandatory internal properties; and import seed data both from files or as a
    parameter. A config file will be imported first, then any config settings.

    .PARAMETER configFile
    A file containing key/value pairs of properties to be added to configuration. A file with the .ps1 extension should define
    a powershell hashmap. A .json file will be imported as JSON data.

    .PARAMETER configSettings
    A hashmap of key/value pairs to be merged into the configuration object.

    .EXAMPLE
    Initialize-DSCConfiguration -configFile somefile.json -configSettings @{'foo'='bar'}

    #>
    param(
        [string]$configFile,
        [hashtable]$configSettings
    )
    $configuration = @{}
    $configuration['_rolesincluded']  = @()
    $configuration['_rolemap'] = @{}
    $configuration['_sources'] = @{}
    $configuration['_validators'] = @{}

    if ($configFile)
    {
        $f = Get-Item $configFile
        if ($f.Extension.ToLower() -eq ".ps1" ) { $configFileData = gc $configFile | Out-String | iex }
        if ($f.Extension.ToLower() -eq ".json" ) { $configFileData = gc $configFile | ConvertFrom-Json }
        $configuration = Merge-Hashmap $configuration $configFileData
    }

    #merge in config settings
    if ($configSettings) { $configuration = Merge-Hashmap $configuration $configSettings }

    $global:configuration = $configuration
}
function Set-DSCConfiguration {
    <#
    .SYNOPSIS
    Sets a property in the configuration object.

    .DESCRIPTION
    Sets a property in the configuration object. By default, if a key already exists, it will not be overridden.

    .PARAMETER key
    The property key

    .PARAMETER value
    The property value

    .PARAMETER force
    If the key already exists, set the passed value. This overrides the default behavior.

    .EXAMPLE
    Set-DSCConfiguration 'foo' 'bar'

    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [string]$key,
    [Parameter(
        Position=1, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $value,
    [switch]$force
    ) 

    #echo "setting $key = $value"
    if (!$configuration[$key]) {
        $configuration[$key] = $value
    }
    else {
        if ($force) { $configuration[$key] = $value }
    }

}

function Validate-DSCConfiguration
{
    <#
    .SYNOPSIS
    Validate a configuration value against specified properties.

    .DESCRIPTION
    A configuration parameter which is specified by a user can be chcked in a role initialization with
    Validate-DSCConfiguration.

    The function returns nothing, but throws an exception if validation fails. The exception is a
    hashmap and contains all the relevant details.

    #todo: Document the format of the exception hashmap

    .PARAMETER key
    The parameter key to check

    .PARAMETER help
    if the parameter is not set, or if it fails validation checks, this help string is returned to assist
    the user.

    .PARAMETER dataType
    This option parmeter helps the validator know what to check. Accepted values are credential, domaincredential and string.

    domaincredential data types use the Check-Credential function to validate the credential.

    .PARAMETER acceptedValues
    An array of case sensitive accepted values. If the value of the parameter is not in this array, it will not validate.

    .EXAMPLE
    Validate-DSCConfiguration 'foo'

    Will simply confirm foo exists.

    .EXAMPLE
    Validate-DSCConfiguration 'foo' 'Foo must be set to bar or baz' -acceptedValues @('bar','baz')

    Will check that foo is set to bar or baz, and if not, will throw an exception with the help string 'Foo must
    be set to bar or baz'. You can catch the exception and do something meaningful with it.
    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [string]$key,
    [Parameter(
        Position=1, 
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [string]$help,
    [ValidateSet('credential','domaincredential','string')]$dataType,
    [array]$acceptedValues
    )

    #initialize the output object
    $vHelp = @{}
    $vHelp['help'] = $help
    $vHelp['acceptedValues'] = $acceptedValues
    $vHelp['dataType'] = $dataType
    $vHelp['found'] = $true
    $vHelp['valid'] = $true
    $vHelp['key'] = $key

    #store out the vHelp, we might want it later
    $configuration['_validators'][$key] = $vHelp

    #if configuration is not set, there is not much point in continuing
    if (!$configuration) { throw "Configuration object not set. Create an empty hash map called configuration." }

    #if the key isn't set, it's time to go
    if (!$configuration[$key])
    {
        $vHelp['found'] = $false
        $vHelp['valid'] = $false
        throw $vHelp
    }

    if ($dataType -eq "domaincredential")
    {
        if (!(Check-Credential $configuration[$key]))
        {
            $vHelp['valid'] = $false;
            $vHelp['help'] = "Credentials did not validate"
        }
    }
    if (!$vHelp['valid']) { throw $vHelp }
}
Set-Alias -Name Require-DSCConfiguration -Value Validate-DSCConfiguration

function Get-DSCConfigrationFromUser
{
    <#
    .SYNOPSIS
    Uses an exception from Validate-DSCConfiguration to prompt the user.

    .PARAMETER properties
    This is an exception hashmap thrown by Validate-DSCConfiguration. For an example of the format
    see that function.

    #>
    #Rather than take discreet settings, this takes the exception thrown by Validate-DSCConfiguration
    Param(
        $properties
    )
    $prompt = "Enter value for [$($properties.key)]"
    if ($properties.help) { $prompt += "( $($properties.help) )" }
    if (@('credential','domaincredential').contains($properties.dataType)) { Return (Get-Credential -Message $prompt ) }

    return (Read-Host -Prompt $prompt )
}

function Get-DSCConfigFromVmware
{
    <#
    .SYNOPSIS
    Get a configuration parameter from VMWare

    .DESCRIPTION
    #todo: Document how to use this.

    If you know how to inject guestinfo properties to VMWare guests, this will help.
    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $key)
	$command = '@echo off
"C:\Program Files\VMWare\VMware Tools\vmtoolsd.exe" --cmd "info-get %1" > %TEMP%\%1'
	
    $command | Out-File -FilePath $ENV:TEMP\vmvar.bat -Encoding ascii
    $erroractionpreference = "Stop"
    $vmkey = "guestinfo.$key"
    try
    {
        $baz = & $ENV:TEMP\vmvar.bat $vmkey 2`>`&1
        $value = gc $ENV:TEMP\$vmkey
        if ($value) { $configuration[$key] = $value }
    }
    catch
    {

    }
}
