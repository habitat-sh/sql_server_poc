param($User, $Password, $Domain, $SqlSharePath, $SqlShareUser, $SqlSharePassword)

$ProgressPreference = 'SilentlyContinue'

Write-Host "Downloading sql server 2017 cu 20..."
mkdir c:\cu
Invoke-WebRequest https://download.microsoft.com/download/C/4/F/C4F908C9-98ED-4E5F-88D5-7D6A5004AEBD/SQLServer2017-KB4541283-x64.exe -OutFile c:\cu\update.exe

mkdir c:\sql_setup_temp
Invoke-WebRequest https://download.microsoft.com/download/5/2/2/522EE642-941E-47A6-8431-57F0C2694EDF/SQLServer2017-SSEI-Eval.exe -OutFile c:\sql_setup_temp\sqlsvr.exe
Start-Process c:\sql_setup_temp\sqlsvr.exe -ArgumentList "/ACTION=Download /MEDIAPATH=c:\sql_setup_temp /MEDIATYPE=Cab /QUIET" -Wait
Start-Process c:\sql_setup_temp\SQLServer2017-x64-ENU.exe -ArgumentList "/x:c:\sql_setup /u" -Wait

# Create a share where we will backup the db on the primary node and restore to the 
# secondary. We make it accesible to "Everyone" because the sql1 and sql2 machine accounts
# will write/read from here.
# TODO: maybe come up with a way to NOT give full access to everyone
mkdir c:\backup
New-SmbShare -Name backup -Path c:\backup -FullAccess Everyone

$username = "$Domain\$User"

# Just in case you want to cleanup the AD entries setup during clustering,
# you need to run those tasks locally because they do not work from a remote
# session. This creates a scheduled task that you can invoke remotely and will
# run them from a local context. In a remote shell you would run:
# Start-ScheduledTask -TaskName ad_cleanup
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy bypass -command c:\terraform\ad_cleanup.ps1"
Register-ScheduledTask -Force -Password $Password -User $username -TaskName ad_cleanup -Action $action -RunLevel Highest

# We want to run the supervisor as a domain admin. This gives our domain admin user
# the privileges to run as a service and then edits the Habitat windows service entry
# to run under the domain admin account.

# TODO: create a GMSA account to run under for the extra enterprise inclined and run habitat as
# that user. This will mean making several changes to ensure all works nice under that account
# for now we run as GOD because that makes everything "just work"
Add-Type -TypeDefinition (Get-Content "$PSScriptRoot\LsaWrapper.cs" | Out-String)
$lsa_wrapper = New-Object -type LsaWrapper
$lsa_wrapper.SetRight($username, "SeServiceLogonRight")
$oService = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name = 'habitat'"
$oService.Change($null,$null,$null,$null,$null,$null,$username,$password) | Out-Null
Restart-Service -Name Habitat

# We install before loading because this plays more nicely with terraform logging
# Otherwise the supervisor will log the progress bar in non-tty mode which emits one line
# each time progress increments and fills the console buffer
hab pkg install mwrock/sqlserver-ha/14.0.1000 --ignore-install-hook --channel unstable

hab svc load mwrock/sqlserver-ha -s at-once --channel sql_update

# We expect a reboot to be required after enabling the windows failovering
# features.
Write-Host "Waiting for machine to require reboot..."
$featureState = (Get-WindowsFeature Failover-Clustering).InstallState
while($featureState -ne "InstallPending") {
    Start-Sleep -seconds 1
    $featureState = (Get-WindowsFeature Failover-Clustering).InstallState
}
Write-Host "Reboot needed..."
