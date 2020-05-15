# Create an Availability Set for the SQL Nodes
resource "azurerm_availability_set" "reference-architecture-mssql" {
  name                = "reference-architecture-mssql"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count = 2
  managed             = true

  tags = {
    X-Dept        = "${var.tag_dept}"
    X-Customer    = "${var.tag_customer}"
    X-Project     = "${var.tag_project}"
    X-Application = "${var.tag_application}"
    X-Contact     = "${var.tag_contact}"
    X-TTL         = "${var.tag_ttl}"
  }
}

resource "azurerm_lb" "reference-architecture-mssql_lb" {
  name                = "reference-architecture-mssql_lb"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "lb_front_end"
    subnet_id                     = "${azurerm_subnet.reference-architecture-mssql-subnet.id}"
    private_ip_address_allocation = "static"
    private_ip_address = "10.0.10.201"
  }
}
resource "azurerm_lb_backend_address_pool" "reference-architecture-mssql_pool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.reference-architecture-mssql_lb.id}"
  name                = "reference-architecture-mssql_pool"
}
resource "azurerm_lb_probe" "reference-architecture-mssql_probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.reference-architecture-mssql_lb.id}"
  name                = "reference-architecture-mssql_probe"
  port                = 59999
}
resource "azurerm_lb_rule" "reference-architecture-mssql_rule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.reference-architecture-mssql_lb.id}"
  name                           = "reference-architecture-mssql_rule"
  protocol                       = "Tcp"
  frontend_port                  = 8888
  backend_port                   = 8888
  frontend_ip_configuration_name = "lb_front_end"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.reference-architecture-mssql_pool.id}"
  probe_id                       = "${azurerm_lb_probe.reference-architecture-mssql_probe.id}"
  enable_floating_ip             = true
}
# Create the Public IPs for SQL Nodes

resource "azurerm_public_ip" "sql_pip" {
  count               = 2
  name                = "sql${count.index}-${random_id.instance_id.hex}-pip"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  allocation_method   = "Static"
}

# Create the NICs for the SQL nodes

resource "azurerm_network_interface" "sql_nic" {
  count                     = 2
  name                      = "sql${count.index}-${random_id.instance_id.hex}-nic"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "sql${count.index}_ipconfig"
    subnet_id                     = "${azurerm_subnet.reference-architecture-mssql-subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.sql_pip.*.id[count.index]}"
  }

  tags {
    X-Dept        = "${var.tag_dept}"
    X-Customer    = "${var.tag_customer}"
    X-Project     = "${var.tag_project}"
    X-Application = "${var.tag_application}"
    X-Contact     = "${var.tag_contact}"
    X-TTL         = "${var.tag_ttl}"
  }
}

resource "azurerm_network_interface_security_group_association" "sql_nic" {
  count                   = 2
  network_interface_id    = "${azurerm_network_interface.sql_nic.*.id[count.index]}"
  network_security_group_id = "${azurerm_network_security_group.reference-architecture-mssql.id}"
}

resource "azurerm_network_interface_backend_address_pool_association" "reference-architecture-mssql_pool_sql" {
  count                   = 2
  network_interface_id    = "${azurerm_network_interface.sql_nic.*.id[count.index]}"
  ip_configuration_name   = "sql${count.index}_ipconfig"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.reference-architecture-mssql_pool.id}"
}
# Create the SQL Nodes
resource "azurerm_virtual_machine" "sql" {
  depends_on            = ["azurerm_virtual_machine.dc"]
  count                 = 2
  name                  = "sql${count.index}"
  location              = "${var.azure_region}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.sql_nic.*.id[count.index]}"]
  vm_size               = "Standard_D3_v2"
  delete_os_disk_on_termination = true
  availability_set_id   = "${azurerm_availability_set.reference-architecture-mssql.id}"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "sql${count.index}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "sql${count.index}"
    admin_username = "${var.azure_image_user}"
    admin_password = "${var.azure_image_password}"
    custom_data    = "${file("./files/winrm.ps1")}"
  }

  os_profile_windows_config {
    provision_vm_agent = true
    winrm = {
      protocol = "http"
    }
    # Auto-Login's required to configure WinRM
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.azure_image_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.azure_image_user}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "${file("./files/FirstLogonCommands.xml")}"
    }
  }

  tags {
    X-Dept        = "${var.tag_dept}"
    X-Customer    = "${var.tag_customer}"
    X-Project     = "${var.tag_project}"
    X-Application = "${var.tag_application}"
    X-Contact     = "${var.tag_contact}"
    X-TTL         = "${var.tag_ttl}"
  }

  connection {
    host     = "${azurerm_public_ip.sql_pip.*.ip_address[count.index]}"
    type     = "winrm"
    port     = 5985
    https    = false
    timeout  = "2m"
    user     = "${var.azure_image_user}"
    password = "${var.azure_image_password}"
  }
  provisioner "file" {
    source      = "files/bootstrap_hab.ps1"
    destination = "c:/terraform/bootstrap_hab.ps1"
  }
  provisioner "file" {
    source      = "files/config_sql.ps1"
    destination = "c:/terraform/config_sql.ps1"
  }
  provisioner "file" {
    source      = "files/config_sql2.ps1"
    destination = "c:/terraform/config_sql2.ps1"
  }
  provisioner "file" {
    source      = "files/LsaWrapper.cs"
    destination = "c:/terraform/LsaWrapper.cs"
  }
  provisioner "file" {

    source      = "files/join_domain.ps1"
    destination = "C:/terraform/join_domain.ps1"
  }
  provisioner "file" {
    source      = "files/cleanup.ps1"
    destination = "C:/terraform/cleanup.ps1"
  }
    provisioner "file" {
    source      = "files/cleanup_db.ps1"
    destination = "C:/terraform/cleanup_db.ps1"
  }
  provisioner "file" {
    source      = "files/ad_cleanup.ps1"
    destination = "C:/terraform/ad_cleanup.ps1"
  }
  provisioner "file" {
    content     = "${data.template_file.sql_toml.rendered}"
    destination = "C:/hab/user/sqlserver-ha/config/user.toml"
  }
  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:/terraform/bootstrap_hab.ps1 -PermanentPeer ${azurerm_network_interface.dc_nic.private_ip_address} -AutomateApp '${var.automate_application}' -AutomateEnv '${var.automate_environment}' -AutomateSite '${var.automate_site}' -AutomateToken '${var.automate_token}' -AutomateIp '${var.automate_ip}'\"",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -command \"C:/terraform/join_domain.ps1 -ADIP ${azurerm_network_interface.dc_nic.private_ip_address} -User ${var.azure_image_user} -Password '${var.azure_image_password}' -Domain ${var.domain_name}\"",
    ]
  }
  provisioner "local-exec" {
    working_dir = "files"
    command = "sleep 60"
  }
  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:/terraform/config_sql.ps1 -User ${var.azure_image_user} -Password '${var.azure_image_password}' -Domain ${var.domain_name}\"",
    ]
  }
  provisioner "local-exec" {
    working_dir = "files"
    command = "sleep 60"
  }
  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:/terraform/config_sql2.ps1 -User ${var.azure_image_user} -Password '${var.azure_image_password}' -Domain ${var.domain_name}\"",
    ]
  }
}
data "template_file" "sql_toml" {
  template = "${file("${path.module}/files/sql.toml")}"

  vars {
    domain = "${var.domain_name}"
    user = "${var.azure_image_user}"
    password = "${var.azure_image_password}"
    dc_name = "${azurerm_virtual_machine.dc.name}"
  }
}
