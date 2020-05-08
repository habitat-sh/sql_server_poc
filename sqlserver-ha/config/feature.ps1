Configuration EnableAlwaysOn
{
    Import-DscResource -ModuleName SqlServerDsc

    Node 'localhost' {
        SqlAlwaysOnService 'EnableAlwaysOn'
        {
            Ensure       = 'Present'
            InstanceName = "{{cfg.instance}}"
            ServerName   = $env:computername
        }
    }
}
