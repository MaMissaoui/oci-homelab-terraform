variable "oci_connection" {
  type = object({
    tenancy_ocid     = string
    user_ocid        = string
    fingerprint      = string
    private_key_path = string
    region           = optional(string, "eu-frankfurt-1")
  })
}

variable "general" {
  type = object({
    compartment_name    = optional(string, "mamsoft")
    main_network_cidr   = optional(string, "172.16.0.0/16")
    private_subnet_cidr = optional(string, "172.16.0.0/24")
  })
  default = {}
}

variable "availability_domain" {
  type    = number
  default = 1
}

variable "vm" {
  type = object({
    name                = optional(string, "mamsoft")
    shape               = optional(string, "VM.Standard.A1.Flex")
    cpus                = optional(number, 4)
    mem_size            = optional(number, 24)
    disk_size           = optional(number, 200)
    image_name          = optional(string, "Canonical-Ubuntu-24.04-aarch64")
    private_ip          = optional(string, "172.16.0.2")
    ssh_public_keys     = list(string)
    os = object({
      hostname  = optional(string, "mamsoft")
      username  = optional(string, "mamsoft")
      password  = optional(string, "")
      force_dns = optional(list(string), [])
      wg_config = optional(map(string), {})
    })
    daily_backups  = optional(number, 3)
    weekly_backups = optional(number, 2)
  })
}
