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
variable "address_space" {
  type        = list(string)
  description = "VNet address space"
}

variable "address_prefixes_1" {
  type        = list(string)
  description = "address space for subnet 1"
}

variable "address_prefixes_2" {
  type        = list(string)
  description = "address space for subnet 2"
}

