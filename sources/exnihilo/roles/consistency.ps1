Set-DSCConfiguration "consistencyEnabled" $false

$configuration['_rolesincluded'] += "exnihilo/consistency"

Configuration Role_exnihilo_consistency {
    Script exnihilo_consistency {
        GetScript = { return @{} }
        TestScript = { return $false }
        SetScript = Format-DSCScriptBlock -includeDSCConfiguration -node @{} -scriptBlock {
            if ($DSCConfiguration.consistencyEnabled)
            {
                & schtasks /Change /tn "\Microsoft\Windows\Desired State Configuration\Consistency" /ENABLE
                & schtasks /Change /tn "\Microsoft\Windows\Desired State Configuration\DSCRestartBootTask" /ENABLE
            }
            else
            {
                & schtasks /Change /tn "\Microsoft\Windows\Desired State Configuration\Consistency" /DISABLE
                & schtasks /Change /tn "\Microsoft\Windows\Desired State Configuration\DSCRestartBootTask" /DISABLE
            }
        }
    }
}