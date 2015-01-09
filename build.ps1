if (Test-Path $PSScriptRoot\exnihilo.psm1 ) { Remove-Item $PSScriptRoot\exnihilo.psm1  }
(Get-ChildItem $PSScriptRoot\functions\*.ps1) | % { Get-Content $_.FullName | Out-File $PSScriptRoot\exnihilo.psm1 -Append }
"Export-ModuleMember -Function *" | Out-File $PSScriptRoot\exnihilo.psm1 -Append