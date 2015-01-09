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
