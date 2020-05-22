////////////////////////////////
// Azure Connection

variable "azure_region" {
  default = "West US"
  description = "The Azure region where we will build resources and instances"
}

variable "azure_sub_id" {
  default = "xxxxxxx-xxxx-xxxx-xxxxxxxxxx"
  description = "The Azure subscription ID for your account"
}

variable "azure_tenant_id" {
  default = "xxxxxxx-xxxx-xxxx-xxxxxxxxxx"
  description = "Azure tenant ID for your tenant"
}

variable "azure_client_id" {
  default = "xxxxxxx-xxxx-xxxx-xxxxxxxxxx"
  description = "Azure client ID for your client"
}

variable "azure_client_secret" {
  default = "xxxxxxx-xxxx-xxxx-xxxxxxxxxx"
  description = "Azure client secret for your client"
}

variable "azure_public_key_path" {
  default = "/path/to/ssh/key"
  description = "Public key for SSH configuration to instances"
}

variable "azure_private_key_path" {
  default = "/path/to/ssh/key"
  description = "Private key that corresponds to azure_public_key_path"
}

////////////////////////////////
// Required Tags

variable "tag_customer" {
  description = "tag_customer is the customer tag which will be added to AWS"
}

variable "tag_project" {
  description = "tag_project is the project tag which will be added to AWS"
}

variable "tag_dept" {
  description = "tag_dept is the department tag which will be added to AWS"
}

variable "tag_contact" {
  description = "tag_contact is the contact tag which will be added to AWS"
}

variable "tag_application" {
  default = "HabManagedAzure"
  description = "tag_application is the application tag which will be added to AWS"
}

variable "tag_ttl" {
  default = 4
  description = "Time, in hours, the environment should be allowed to live"
}

////////////////////////////////
// OS Variables

variable "azure_image_user" {
  default = "azureuser"
  description = "Usernamem to login to instances"
}

variable "azure_image_password" {
  default = "Azur3pa$$word"
  description = "Password for azurerm_image_user"
}

variable "origin" {
  default = ""
  description = "Habitat package origin"
}


////////////////////////////////
// Chef Automate

variable "channel" {
  default="current"
  description = "channel is the habitat channel which will be used for installing A2"
}

variable "automate_application" {
  default = "sqlserver-ha"
  description = "application name for automate application view"
}

variable "automate_environment" {
  default = "demo"
  description = "environment name for automate application view"
}

variable "automate_site" {
  default = "us-west-2"
  description = "site name for automate application view"
}

variable "automate_ip" {
  default = ""
  description = "ip address of automate instance"
}

variable "automate_token" {
  default = ""
  description = "token for automate instance"
}

variable "domain_name" {
 default = "demo.local"
 description = "Domain Name of AD environment"
}
