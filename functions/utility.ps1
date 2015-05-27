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
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($no, $yes)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    
    return $result
}
