variable "hub-sub" {
  type = string
  default = "43d3f387-48d5-44d4-973f-32d4254cc4f3"
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
}

# VNET Variable
variable "ea_vnet1_address_space" {
  type        = list(string)
  description = "EA VNet address space"
}

variable "ea_vnet2_address_space" {
  type        = list(string)
  description = "EA VNet address space"
}

variable "ae_vnet1_address_space" {
  type        = list(string)
  description = "AE VNet address space"
}

variable "ea_vnet1_address_prefixes_1" {
  type        = list(string)
  description = "address space for subnet 1"
}

variable "ea_vnet1_address_prefixes_2" {
  type        = list(string)
  description = "address space for subnet 2"
}

variable "ea_vnet2_address_prefixes_1" {
  type        = list(string)
  description = "address space for subnet 1"
}

variable "ea_vnet2_address_prefixes_2" {
  type        = list(string)
  description = "address space for subnet 2"
}

variable "ae_vnet1_address_prefixes_1" {
  type        = list(string)
  description = "address space for subnet 1"
}

variable "ae_vnet1_address_prefixes_2" {
  type        = list(string)
  description = "address space for subnet 2"
}