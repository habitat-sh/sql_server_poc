param($PermanentPeer, $AutomateApp, $AutomateEnv, $AutomateSite, $AutomateToken, $AutomateIp)

# Set TLS 1.2
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord

SETX HAB_LICENSE accept-no-persist /m
$env:HAB_LICENSE="accept-no-persist"

Set-ExecutionPolicy Bypass -Scope Process -Force
# Add windows defender exclusions for hab binary
Add-MpPreference -ExclusionPath C:\Users\azureuser\AppData\Local\Temp\*\*\*\hab.exe
Add-MpPreference -ExclusionPath C:\ProgramData\Habitat\hab.exe

Invoke-Expression (Invoke-WebRequest https://raw.githubusercontent.com/habitat-sh/habitat/master/components/hab/install.ps1)

# seen this randomly fail with flaky internet errors
# so try until we succeed
do{
    hab pkg install core/windows-service
}
until($LASTEXITCODE -eq 0)

New-NetFirewallRule -DisplayName 'Habitat TCP' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9631,9638
New-NetFirewallRule -DisplayName 'Habitat UDP' -Direction Inbound -Action Allow -Protocol UDP -LocalPort 9638

$launcherArgsVal = "--no-color --peer $PermanentPeer"
if(![string]::IsNullOrEmpty($AutomateIp)) {
    $launcherArgsVal += " --event-stream-application=$automateApp --event-stream-environment=$automateEnv --event-stream-site=$AutomateSite --event-stream-url=${AutomateIp}:4222 --event-stream-token=$AutomateToken"
}
if($PermanentPeer) {
    $svcPath = Join-Path $env:SystemDrive "hab\svc\windows-service"
    [xml]$configXml = Get-Content (Join-Path $svcPath HabService.dll.config)
    $launcherArgs = $configXml.configuration.appSettings.SelectNodes("add[@key='launcherArgs']")[0]
    $launcherArgs.SetAttribute("value", $launcherArgsVal)
    $configXml.Save((Join-Path $svcPath HabService.dll.config))
}

Start-Service Habitat
