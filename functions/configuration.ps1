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
