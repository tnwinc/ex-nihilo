Push-Location $PSScriptRoot

#Copy-Item dsc\* $env:ProgramFiles\WindowsPowerShell\Modules -Recurse -Force

Add-DSCRolemap -roleMapName "samplemap" -Roles "sample/example"

Pop-Location

