hab svc unload mwrock/sqlserver-ha
Stop-Service 'MSSQL$HAB_SQL_SERVER'
C:\sql_setup\setup.exe /Q /ACTION=Uninstall /FEATURES=SQLENGINE /SUPPRESSPRIVACYSTATEMENTNOTICE=True /INSTANCENAME=HAB_SQL_SERVER
if($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Remove-Item (Join-path $(hab pkg path mwrock/sqlserver-ha) INSTALL_HOOK_STATUS)
Remove-Item c:\hab\svc\sqlserver-ha\data -Recurse
