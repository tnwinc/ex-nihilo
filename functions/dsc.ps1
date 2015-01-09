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
        #before going any further we need to initialize the working directory
        Set-DSCConfiguration "mofDirectory" "$($env:TEMP)\mof"
        if (!(test-path ($configuration.mofDirectory))) { new-item ($configuration.mofDirectory) -Type directory }
        #if (Test-Path ($configuration.mofDirectory + "\*") ) { Remove-Item ($configuration.mofDirectory+"\*") -Recurse -Force -ErrorAction Stop }

        ActualConfiguration -ConfigurationData $configData -OutputPath $configuration.mofDirectory
    }
}
