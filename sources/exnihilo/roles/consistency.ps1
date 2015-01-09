Set-DSCConfiguration "consistencyEnabled" $false

$configuration['_rolesincluded'] += "exnihilo/consistency"

Configuration Role_exnihilo_consistency {
    Script exnihilo_consistency {
        GetScript = { return @{} }
        TestScript = { return $false }
        SetScript = Format-DSCScriptBlock -includeDSCConfiguration -node @{} -scriptBlock {
            if ($DSCConfiguration.consistencyEnabled)
            {
                Get-ScheduledTask -TaskPath "\Microsoft\Windows\Desired State Configuration\" -TaskName "Consistency" | Enable-ScheduledTask
            }
            else
            {
                Get-ScheduledTask -TaskPath "\Microsoft\Windows\Desired State Configuration\" -TaskName "Consistency" | Disable-ScheduledTask
            }
        }
    }
}