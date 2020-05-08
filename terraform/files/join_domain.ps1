param($ADIP, $Domain, $User, $Password)

Get-NetAdapter | Set-DnsClientServerAddress -ServerAddresses $ADIP
$servers = (Get-DnsClientGlobalSetting).SuffixSearchList
$servers = @($Domain) + $servers
Set-DnsClientGlobalSetting -SuffixSearchList $servers
$safe_password = $Password | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("$domain\$user",$safe_password)

$joined = $false
while(!$joined) {
    Write-Host "Attempting to join $Domain"
    try {
        Add-Computer -DomainName $Domain -Credential $credential -Force -ErrorAction Stop
        $joined = $true
    } catch{ Start-Sleep -Seconds 10 }
}
Write-Host "Succesfully joined $Domain"
Restart-Computer -Force
