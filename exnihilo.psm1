function Initialize-DSCConfiguration
{
    param(
        $configFile,
        $configSettings
    )
    $configuration = @{}
    $configuration['_rolesincluded']  = @()
    $configuration['_rolemap'] = @{}
    $configuration['_sources'] = @{}
    $configuration['_validators'] = @{}
    #before going any further we need to initialize the working directory
    Set-DSCConfiguration "mofDirectory" "$($env:TEMP)\mof"
    if (!(test-path ($configuration.mofDirectory))) { new-item ($configuration.mofDirectory) -Type directory }
    if (Test-Path ($configuration.mofDirectory + "\*") ) { Remove-Item ($configuration.mofDirectory+"\*") -Recurse -Force -ErrorAction Stop }

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
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $key,
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
    param(  
    [Parameter(
        Position=0, 
        Mandatory=$true, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $key,
    [Parameter(
        Position=1, 
        Mandatory=$false, 
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)
    ]
    $help,
    [ValidateSet('credential','domaincredential','string')]$dataType,
    $acceptedValues
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
    param(
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        $source,
        $namespace
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
        Write-Output $_.targetObject
        exit
    }
}

function Format-DscScriptBlock()
{
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
    param(  
        [Parameter(
            Position=0, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        $nodeName = "localhost",
        $actualRoles,
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
        ActualConfiguration -ConfigurationData $configData -OutputPath $configuration.mofDirectory
    }
}
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
Function ConvertTo-EncodedJSON {
    param(
        [Parameter(
            Position=0, 
            Mandatory=$true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)
        ]
        $inputObject
    )
    $json = $inputObject | ConvertTo-Json | Out-String
    $enc = [System.Web.HttpUtility]::UrlEncode($json)
    return $enc
}


function Merge-Hashmap
{
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
    Param(
        $title,
        $message
    )
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($no, $yes)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    
    return $result
}
Export-ModuleMember -Function *
