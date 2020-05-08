param($Domain, $Password)
Add-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools
$pass = ConvertTo-SecureString -string $Password -AsPlainText -Force
Install-ADDSForest -DomainName $Domain -InstallDns -SafeModeAdministratorPassword $pass -Force

mkdir c:\witness
New-SmbShare -Name witness -Path c:\witness -FullAccess Everyone
