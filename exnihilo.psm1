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
function Initialize-DSCSource
{
    <#
    .SYNOPSIS
    Initializes a DSC source, running the init.ps1 script and adding it to the sources array.

    .PARAMETER source
    A path to a DSC source

    .PARAMETER namepsace
    The namespace of the source. If not specified, the last directory in the source path is used.

    .EXAMPLE
    Initialize-DSCSource C:\somefiles\foo

    Will initialize source at c:\somefiles\foo as the foo namespace

    .EXAMPLE
    Initialize-DSCSource c:\somefiles\bar -namespace foo
    
    Will initialize source at c:\somefiles\bar as the foo namespace
    #>
    param(
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        $source,
        [string]$namespace
    )
    #Write-Output "** $source"
    $source = Get-Item $source
    if (!$namespace) { $namespace = $source.Name }
    $sourceinfo = @{'namespace'=$namespace; 'path' = $source.FullName}
    $configuration['_sources'][$namespace] = $sourceinfo
    try
    {
        if (Test-Path "$($source.FullName)\init.ps1") { . "$($source.FullName)\init.ps1" }
    }
    catch
    {
        Write-Error "Fatal error initializing $source"
        if($_.targetObject) { Write-Error $_.targetObject }
        Write-Error $_.Exception
        Write-Error $_.ErrorDetails
        Write-Error $_.InvocationInfo
        exit
    }
}

function Format-DscScriptBlock()
{
    <#
    .SYNOPSIS
    Returns a string of powershell with variables substituted as absolute values.

    .DESCRIPTION
    A DSC script resource is not aware of any of the parameters in the configuration block. This
    function will take scriptBlock and substitute parameters from node into it. For example, if
    
    node = @{'foo'='bar'}
    
    and scriptBlock

    Write-Output "$foo"

    The function will return:

    Write-Output "bar"

    For this reason it is critical that all string variables be wrapped in quotes when used. This is
    contrary to what is uaully done in a native script. This also means it's impossible to pass anything
    other than a string or number. Objects cannot be passed.

    The exnihilo/example role demonstrates how this is used.

    .PARAM includeDSCConfiguration
    If specified, the entire $configuration object will be inluded and accessible inside the script block as a hashmap. You can
    use these variables like any other, they do not need to be quote wrapped.

    .PARAM node
    A hashtable of key/value pairs to be expanded inside the block

    .PARAM scriptBlock
    A block of powershell.

    #>
    param(
        [switch]$includeDSCConfiguration,
        [parameter(Mandatory=$true)]
        [System.Collections.Hashtable] $node,
        [parameter(Mandatory=$true)]
        [System.Management.Automation.ScriptBlock] $scriptBlock
    )
    $result = ""
    if ($includeDSCConfiguration)
    {
        $result += "[System.Reflection.Assembly]::LoadWithPartialName(`"System.web`")`n"
        $result += "`$DSCConfiguration = ([System.Web.HttpUtility]::UrlDecode('$(ConvertTo-EncodedJSON $configuration)')) | ConvertFrom-Json" 
    }
    $result += $scriptBlock.ToString();
    foreach( $key in $node.Keys )
    {
      $result = $result.Replace("`$$key", $node[$key]);
    }

    return $result;
}

function New-DSCConfiguration
{
    <#
    .SYNOPSIS
    This goes through the process of actually running all the roles' DSC configuration definitions.

    .PARAMETER nodeName
    The computer name for the role. Useful for pull/push setups. Defaults to localhost.

    .PARAMETER actualRoles
    An array of the actual roles (role maps must be expanded) to be applied, in order.

    .PARAMETER generateMOF
    If specified, the MOF file will be generated, otherwise the configurations are executed but 
    the MOF not generated.

    .EXAMPLE
    New-DSCConfiguration -actualRoles @('exnihilo/consistency') -generateMOF

    #>
    param(  
        [Parameter(
            Position=0, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        [string]$nodeName = "localhost",
        [Parameter(
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )
        ][array]$actualRoles,
        [switch]$generateMOF
    )
    if (!$actualRoles) { $actualRoles = $configuration['actualRoles'] }
    $configData = @{
        AllNodes = @(
            @{
                NodeName="*"
                PSDscAllowPlainTextPassword=$true
            },
            @{
                NodeName=$nodeName
            }
        )
    }
    Configuration ActualConfiguration {
        Node $AllNodes.NodeName {
            LocalConfigurationManager {
                RebootNodeIfNeeded = $true
            }
            Import-DSCActualRoles -actualRoles $actualRoles -invokeConfiguration
        }
    }
    if ($generateMOF)
    {
        #before going any further we need to initialize the working directory
        Set-DSCConfiguration "mofDirectory" "$($env:TEMP)\mof"
        if (!(test-path ($configuration.mofDirectory))) { new-item ($configuration.mofDirectory) -Type directory | Out-Null }
        #if (Test-Path ($configuration.mofDirectory + "\*") ) { Remove-Item ($configuration.mofDirectory+"\*") -Recurse -Force -ErrorAction Stop }

        ActualConfiguration -ConfigurationData $configData -OutputPath $configuration.mofDirectory | Out-Null
    }
}
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
Function ConvertTo-EncodedJSON {
    <#
    .SYNOPSIS
    Takes a hashmap and returns a URL encoded string of JSON

    .PARAMETER inputObject
    The object to be encoded

    .EXAMPLE
    ConvertTo-EncodedJSON @{'foo'='bar'}
    #>
    param(
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        $inputObject
    )
    $json = $inputObject | ConvertTo-Json -Depth 32 -Compress | Out-String
    $enc = [System.Web.HttpUtility]::UrlEncode($json)
    return $enc
}


function Merge-Hashmap
{
    <#
    .SYNOPSIS
    Merges two hashmaps

    .DESCRIPTION
    Merge two hashmaps, (optionally) preserving the original values. Does not handle nested hashmaps.

    .PARAMETER baseMap
    The hashmap being added to

    .PARAMETER additionalMap
    The hashmap to merge into baseMap

    .PARAMETER force
    If specified, all keys from additionalMap will be merged into baseMap, even if they already exist.

    .EXAMPLE
    $foo = Merge-Hashmap @{'foo'='bar'} @{'foo'='baz','fud'='biz'}

    Returns @{'foo'='bar','fud'='biz}

    .EXAMPLE
    $foo = Merge-Hashmap @{'foo'='bar'} @{'foo'='baz','fud'='biz'} -force

    Returns @{'foo'='baz','fud'='biz}

    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $baseMap,
    [Parameter(
        Position=1, 
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $additionalMap,
    [switch]$force
    )
	
    $out = $baseMap

    $additionalMap.GetEnumerator() | % {
        if (!$out[$_.key])
        {
            $out[$_.key] = $_.value
        }
        else
        {
            if ($force) { $out[$_.key] = $_.value }
        }
    }

    return $out
}

function ConvertTo-MaskLength {
  <#
    .Synopsis
      Returns the length of a subnet mask.
    .Description
      ConvertTo-MaskLength accepts any IPv4 address as input, however the output value
      only makes sense when using a subnet mask.
    .Parameter SubnetMask
      A subnet mask to convert into length
  #>
 
  [CmdLetBinding()]
  param(
    [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
    [Alias("Mask")]
    [Net.IPAddress]$SubnetMask
  )
 
  process {
    $Bits = "$( $SubnetMask.GetAddressBytes() | ForEach-Object { [Convert]::ToString($_, 2) } )" -replace '[\s0]'
 
    return $Bits.Length
  }
}

function ConvertTo-Base64 {
    <#
    .SYNOPSIS
    Convert a string to Base64
    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String[]]$string
    ) 
    $b = [System.Text.Encoding]::UTF8.GetBytes($string)
    $out = [System.Convert]::ToBase64String($b)
    return $out
}

function ConvertFrom-Base64 {
    <#
    .SYNOPSIS
    Convert a string from Base64
    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    [String[]]$string
    ) 
    $b  = [System.Convert]::FromBase64String($string)
    $out = [System.Text.Encoding]::UTF8.GetString($b)
    return $out
}

function Check-Credential {
    <#
    .SYNOPSIS
    Validate a set of Windows domain credentials are valid. Domain portion must be fully qualified: contoso.com\Username or username@contoso.com

    .PARAMETER cred
    As PSCredential object


    #>
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $cred
    ) 
    $domain = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($cred.GetNetworkCredential().Domain)",$cred.GetNetworkCredential().UserName,$cred.GetNetworkCredential().Password)
    if ($domain.name -eq $null) { return $false } else { return $true }
}


Function Read-YesNo
{
    <#
    .SYNOPSIS
    A simple  yes/no promot where the result evaluates true/false

    .PARAMETER tile
    Tile of the prompt dialog

    .PARAMETER message
    Message in the promopt dialog
    #>
    Param(
        $title,
        $message
    )
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes'
    $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No'
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($no, $yes)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    
    return $result
}
Export-ModuleMember -Function *
