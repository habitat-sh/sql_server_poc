resource "azurerm_public_ip" "dc_pip" {
  name                = "dc-${random_id.instance_id.hex}-pip"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "dc_nic" {
  name                      = "dc-${random_id.instance_id.hex}-nic"
  location                  = "${azurerm_resource_group.rg.location}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "dc_ipconfig"
    subnet_id                     = "${azurerm_subnet.reference-architecture-mssql-subnet.id}"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = "${azurerm_public_ip.dc_pip.id}"
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

resource "azurerm_network_interface_security_group_association" "dc_nic" {
  network_interface_id    = "${azurerm_network_interface.dc_nic.id}"
  network_security_group_id = "${azurerm_network_security_group.reference-architecture-mssql.id}"
}

# Create the Domain Controller node
resource "azurerm_virtual_machine" "dc" {
  name                  = "dc"
  location              = "${var.azure_region}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  network_interface_ids = ["${azurerm_network_interface.dc_nic.id}"]
  vm_size               = "Standard_D2_v2"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "dc_osdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "dc"
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
    host     = "${azurerm_public_ip.dc_pip.ip_address}"
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
    source      = "files/create_domain.ps1"
    destination = "C:/terraform/create_domain.ps1"
  }
  provisioner "remote-exec" {
    inline = [
      "PowerShell.exe -ExecutionPolicy Bypass -command \"c:\\terraform\\bootstrap_hab.ps1\"",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "powershell.exe -ExecutionPolicy Bypass -command \"C:/terraform/create_domain.ps1 -Password '${var.azure_image_password}' -Domain ${var.domain_name} \"",
    ]
  }
}
