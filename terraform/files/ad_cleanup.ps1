Install-WindowsFeature RSAT-AD-PowerShell
Remove-Cluster $env:computername -CleanupAD -Force
Remove-ADComputer ag -Confirm:$false
