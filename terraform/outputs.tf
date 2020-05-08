output "domain_controller_public_ip" {
  value = "${azurerm_public_ip.dc_pip.ip_address}"
}
output "sql_public_ips" {
  value = "${azurerm_public_ip.sql_pip.*.ip_address}"
}
output "web_public_ip" {
  value = "${azurerm_public_ip.web_pip.ip_address}"
}
