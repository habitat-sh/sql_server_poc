hab svc status mwrock/sqlserver-ha
if($LASTEXITCODE -eq 0) {
    hab svc unload mwrock/sqlserver-ha
}

$listening = $false
while(!$listening) {
    Write-Host "waiting for sql server to start accepting connections..."
    Start-Sleep -Seconds 3
    try{
        $listening = New-Object System.Net.Sockets.TCPClient -ArgumentList localhost,8888 -ErrorAction SilentlyContinue | ? { $_.Connected }
    } catch {}
}

Import-Module SqlServer
$svr = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "${env:computername}\HAB_SQL_SERVER"
$svr.AvailabilityGroups[0].DropIfExists()
$svr.Databases["ContosoUniversity2"].DropBackupHistory()
$svr.Databases["ContosoUniversity2"].Drop()
disable-SqlAlwaysOn -Path SQLSERVER:\SQL\$env:computername\hab_sql_server -Force
