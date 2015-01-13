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
        Write-Output $_.targetObject
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
