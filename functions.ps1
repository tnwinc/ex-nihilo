<#
This is a legacy file to support older scripts that relied on importing functions.ps1 to get started.
New scripts should import exnihilo.psm1
#>

(Get-ChildItem $PSScriptRoot\functions\*.ps1) | % { . $_.FullName }
