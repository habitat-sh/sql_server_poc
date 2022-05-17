resource "azurerm_public_ip" "web_pip" {
  name                = "web-${random_id.instance_id.hex}-pip"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "web_nic" {
  name                      = "web-${random_id.instance_id.hex}-nic"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "web_ipconfig"
    subnet_id                     = "${azurerm_subnet.reference-architecture-mssql-subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.web_pip.id}"
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

# Create the Domain Controller node
resource "azurerm_virtual_machine" "web" {
  depends_on            = ["azurerm_virtual_machine.dc"]
  name                  = "web"
  location              = "${var.azure_region}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.web_nic.id}"]
  vm_size               = "Standard_D2_v3"
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "web_osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "web"
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
    host     = "${azurerm_public_ip.web_pip.ip_address}"
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
    source      = "files/config_web.ps1"
    destination = "c:/terraform/config_web.ps1"
  }
  provisioner "file" {

    source      = "files/join_domain.ps1"
    destination = "C:/terraform/join_domain.ps1"
  }
  provisioner "file" {
    content     = "${data.template_file.web_toml.rendered}"
    destination = "C:/hab/user/contosouniversity_ag/config/user.toml"
  }

  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:\\terraform\\bootstrap_hab.ps1 -PermanentPeer ${azurerm_network_interface.dc_nic.private_ip_address}\"",
    ]
  }  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:\\terraform\\config_web.ps1\"",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -command \"C:/terraform/join_domain.ps1 -ADIP ${azurerm_network_interface.dc_nic.private_ip_address} -User ${var.azure_image_user} -Password '${var.azure_image_password}' -Domain ${var.domain_name}\"",
    ]
  }
}
data "template_file" "web_toml" {
  template = "${file("${path.module}/files/web.toml")}"

  vars {
    domain = "${var.domain_name}"
    user = "${var.azure_image_user}"
    password = "${var.azure_image_password}"
  }
}
