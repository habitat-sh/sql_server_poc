param($User, $Password, $Domain, $SqlSharePath, $SqlShareUser, $SqlSharePassword)

$username = "$Domain\$User"

# There appears to be a bug in the supervisor that I can only reproduce
# in a newly provisioned environment where the current member is not getting
# gossiped to the other members so each is alone but we need them to be aware
# of eachother before going into the clustering configuration. The only remedy
# from what I can tell is to unload and reload the service. So we will wait for
# the init hook to start which means that all installation and rebooting has
# completed. Then we will kill the init hook (which should just be in a holding
# pattern waiting for the other node) and reload the service.
$init = Get-CimInstance Win32_Process -Filter "name = 'pwsh.exe'" | select CommandLine, ProcessId | ? { $_.CommandLine.EndsWith("init | out-string)`"") }
while($init -eq $null) {
    Write-Host "waiting for init hook to start..."
    Start-Sleep -Seconds 5
    $init = Get-CimInstance Win32_Process -Filter "name = 'pwsh.exe'" | select CommandLine, ProcessId | ? { $_.CommandLine.EndsWith("init | out-string)`"") }
}

hab svc unload mwrock/sqlserver-ha
Stop-Process -Id $init.ProcessId -Force
Start-Sleep -Seconds 3
hab svc load mwrock/sqlserver-ha -s at-once --channel sql_update
