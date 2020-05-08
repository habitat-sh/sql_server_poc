param($PermanentPeer)

# Set TLS 1.2
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord

SETX HAB_LICENSE accept-no-persist /m
$env:HAB_LICENSE="accept-no-persist"

Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.ps1)

# seen this randomly fail with flaky internet errors
# so try until we succeed
do{
    hab pkg install core/windows-service
}
until($LASTEXITCODE -eq 0)

New-NetFirewallRule -DisplayName 'Habitat TCP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9631,9638
New-NetFirewallRule -DisplayName 'Habitat UDP' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 9638

if($PermanentPeer) {
    $svcPath = Join-Path $env:SystemDrive "hab\svc\windows-service"
    [xml]$configXml = Get-Content (Join-Path $svcPath HabService.dll.config)
    $launcherArgs = $configXml.configuration.appSettings.SelectNodes("add[@key='launcherArgs']")[0]
    $launcherArgs.SetAttribute("value", "--no-color --peer $PermanentPeer")
    $configXml.Save((Join-Path $svcPath HabService.dll.config))
}

Start-Service Habitat
