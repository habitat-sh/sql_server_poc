hab pkg install mwrock/contosouniversity

#TODO: The contosouniversity plan should enable this rule
New-NetFirewallRule -DisplayName 'ContosoUniversity' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8099

hab svc load mwrock/contosouniversity_ag --channel unstable --bind database:sqlserver-ha.default
