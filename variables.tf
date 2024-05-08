variable "cidr_block" {
  description = "Value of the Name tag for the cidr block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ipv4_public_cidrs" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "Subnet CIDR blocks (e.g. `10.0.0.0/24`)."
}





