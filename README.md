# Archived Repository
This repository has been archived and will no longer receive updates. 
It was archived as part of the [Repository Standardization Initiative](https://github.com/chef-boneyard/oss-repo-standardization-2025).
If you are a Chef customer and need support for this repository, please contact your Chef account team.

---

# Chef Habitat SQL POC code artifacts

## SQL Server plans

This repository cobntains the following plans:

* `contosouniversity_ag` - A plan to build a web application that interacts with a SQL Server Availability Group pair.
* `sqlserver` - A plan for installing and running a stand alone instance of MS SQL Server 2017.
* `sqlserver_cu20` - Builds on the above plan by including the cumulative update 20 to SQL Server 2017. The idea here is to first load the `sqlserver` package with an `at-once` update strategy and then build and promote this plan to update the SQL Server instance.
* `sqlserver-ha` - This builds a package that is intended to be loaded on at least two servers which the hooks will configure to enlist in a Windows Failover Cluster and include in a SQL Server Availability Group.

Note that all the sql server plans expect the SQL Server installation media to exist in `c:\sql_setup`. This is configurable by editing the `install_media_dir` either in the `default.toml` or in a `user.toml` file. Whatever directory name you use, the `setup.exe` file should be in that directory along with all other supporting setup files and directories included in a SQL SERVER `ISO` or `CAB` file.

## Terraform

In order to build a SQL Server Availability Group in Azure, there are several infrastructure requirements that need to be present in order for things to work. These terraform scripts ensure all is setup correctly. This includes:

* Creating a Domain Controller
* An availability set
* A load balancer configured with rules that listen to the sql port and a probe port matching the availability probe port and a private ip that matches the availability group listener ip.
* 2 SQL VMs joined to the AD domain and members of the availability set and included in the above load balancer pool.
* A web application VM also joined to the domain that binds to the availability group

All VMs are bootstraped with Habitat and the habitat windows service, peered together and the sql instances are loaded with the `sqlserver-ha` package.

For "english" style instructions on creating all required infra see https://github.com/habitat-sh/habitat-aspnet-eff#setting-up-an-azure-demo-lab.

## Cleanup scripts

Because we will not be working in Docker and the SQL Server installation wires itself into the registry that is not automatically cleansed by "uninstalling" the habitat package or removing the local Habitat Studio. There are a few scripts here that perform uninstallation. These scripts are located in the `terraform/files` directory and included in `c:\terraform` on the terraform provisioned SQL nodes:

* `cleanup_db.ps1` - Uninstalls SQL server
* `cleanup.ps1` - Removes all Availability Group configuration on a node. If you also need to run the above `db_cleanup.ps1`, make sure to run this first.
* `ad_cleanup.ps1` - cleans up the Windows Failover Cluster and its AD artifacts. This script cannot be run remotely (winrm/ps remoting) so you must be RDP'd to run it. It only needs to be run on one of the clustered nodes.

## Prerequisites to using this repo to stand up a SQL Availability Group pair

You will need the following in order to use the terraform scripts to stand up infrastructure:

* An azure account with a subscription id and tennant id
* the [azure cli] (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [Terraform](https://www.terraform.io/downloads.html)
* (Optional) [SQL Server Management Studio](https://docs.microsoft.com/en-us/sql/ssms/download-sql-server-management-studio-ssms?view=sql-server-ver15)

## Patching a SQL Server Availability Group cluster

Given the Chef Habitat plans and terraform scripts in this repo along with your own Azure account, you have everything you need to stand up a 2017 SQL Server Availability Group cluster and patch it.

1. `cd` to the `terraform` directory of this repo
1. Login to your azure account with the azure cli by running `az login` which will bring up a browser where you can sign in.
1. Add a `terraform/terraform.tfvars` file (see the example at the end of this readme) and add your azure subscription id and tennant id. The above `az login` command will display these on the console and you can simply copy and paste them.
1. Run `terraform init` to initialize the terraform plan and pull down the necessary terraform plugins.
1. Run `terraform apply` which will display the plan and ask you to enter `yes`.
1. Enter `yes`
1. Focus on your breath. For the next 30 minutes, there is no azure, there is no available or unavailable. We constantly fail over to ourselves. You are always the owning node.
1. When terraform is complete, the 2 SQL nodes are likely still finishing up their Availability Group setup. That could take another 5 minutes to complete.
1. Viewing the supervisor logs (see the next section below on how to do that), you should eventually see both nodes claim `Availability group configuration complete!`
1. In a browser navigate to `http://<WEB_IP>:8099/hab_app/Student` and enter a student. This app is pointed to the Availability Group name and not any individual sql instance.
1. If you have Sql Server Management Studio (SSMS) installed, create a connection to both instances. Connect to `<SQL_IP>,8888` and use `SQL Server Authentication` with username `sa` and password `Pass@word1`. In the left you can expand the databases and see the `ContosoUniversity2` databases are both in a `synchronized` state. You can also expand the `Always On High Availability` nodes to see which node is Primary and which is Secondary. Also the parent server node will display the SQL version.
1. Let's initiate a cluster patch by promoting 14.0.3294: `hab pkg promote mwrock/sqlserver-ha/14.0.3294/20200507152243 sql_update`

Within a minute you should see both nodes updating themselves in the supervisor output. You should see the secondary update first. While this is happening, make sure that the web application is still working and you can view the student data. After about 5 to 10 minutes, the secondary should finish updating and the primary's supervisor output should indicate that it is failing over to the secondary node. At this point it is good to show:

* The SSMS view now has the primary/secondary nodes swaped
* The formerly secondary (now primary) has its version showing `14.0.3294`
* The web app still works, shows the same data we saw earlier and can add another student

After another several minutes both nodes should be updated and control failed back to the original primary node. Now we can show:

* The web app continues to work with no data loss
* Both nodes in SSMS have the updated version
* The Primary/Secondary assignments are back to the nodes they were originally assigned to

## Viewing the Supervisor logs on the SQL Nodes

If you have a Windows laptop, I prefer to run remote shells locally connecting to the public IPs of the deployed nodes. Otherwise, you can RDP to the web node and remote to everything from there.

Given the default username and password you can remote from a local powershell console (Or a powershell console from your RDP session on the web node) by running:

```
$secpasswd = ConvertTo-SecureString 'Azur3pa$$word' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ('DEMO\azureuser', $secpasswd)
Enter-PSSession -ComputerName <public IP> -Credential $credential
```

Then run `gc C:\hab\svc\windows-service\logs\Habitat.log -wait` to stream the Supervisor output.

## Example `terraform.tfvars`

```
azure_region  = "westus2"
azure_sub_id = "<AZURE_SUBSCRIPTION_ID>"
azure_tenant_id = "<AZURE_TENANT_ID>"
tag_customer = "demo"
tag_project = "sql_ha"
tag_dept = "engineering"
tag_contact = "mwrock@chef.io"
```
