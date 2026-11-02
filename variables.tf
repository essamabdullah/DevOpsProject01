variable "os_cloud" {
  type = string
}

variable "name_prefix" {
  description = "Prefix for security groups and ports"
  type        = string
  default     = "vprofile"
}

variable "vm_names" {
  description = "Which vprofile VMs to create (db01, mc01, rmq01, app01, web01). Empty list = all five."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for n in var.vm_names : contains(["db01", "mc01", "rmq01", "app01", "web01"], n)])
    error_message = "vm_names may only contain db01, mc01, rmq01, app01, web01."
  }
}

variable "image_name" {
  description = "Glance image for the 5 VMs (must match 'openstack image list' exactly)"
  type        = string
  default     = "Ubuntu 24.04 LTS"
}

variable "flavor_name" {
  description = "Flavor for db01, mc01, rmq01, web01"
  type        = string
}

variable "app_flavor_name" {
  description = "Flavor for app01 (needs >= 2 GB RAM for Maven); empty = use flavor_name"
  type        = string
  default     = ""
}

variable "network_name" {
  description = "Existing internal network for the VMs (must have internet access via a router)"
  type        = string
}

variable "external_network_name" {
  description = "External network for web01's floating IP; leave empty to skip"
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Existing Nova keypair of type ssh to inject into the instances"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Who may SSH/ping web01; narrow this to your own IP range"
  type        = string
  default     = "0.0.0.0/0"
}

variable "http_allowed_cidr" {
  description = "Who may open the website on web01"
  type        = string
  default     = "0.0.0.0/0"
}

# ---------- Application settings (replace the manual steps in the PDF) ----------

variable "repo_url" {
  type    = string
  default = "https://github.com/hkhcoder/vprofile-project.git"
}

variable "repo_branch" {
  type    = string
  default = "main"
}

variable "db_root_password" {
  description = "MariaDB root password. Avoid | $ ' characters."
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "db_user" {
  type    = string
  default = "admin"
}

variable "db_password" {
  description = "App DB user password. Avoid | $ ' characters."
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "rmq_user" {
  type    = string
  default = "test"
}

variable "rmq_password" {
  type      = string
  sensitive = true
  default   = "test"
}

variable "tomcat_version" {
  type    = string
  default = "9.0.75"
}

variable "java_version" {
  description = "OpenJDK major version on app01 (17 or 11). Switch to 11 if the Maven build fails."
  type        = string
  default     = "11"
}

# ---------- Login / DNS ----------

variable "ubuntu_password" {
  description = "Password for the ubuntu user (console and RDP login); empty = no password. Avoid ' characters."
  type        = string
  sensitive   = true
  default     = ""
}

variable "dns_servers" {
  description = "DNS servers forced inside every VM; empty = use what the subnet's DHCP gives"
  type        = list(string)
  default     = []
}

# ---------- Test desktop (GUI + Firefox) ----------

variable "enable_desktop" {
  description = "Create desktop01, an XFCE + Firefox VM for testing the app from inside the network"
  type        = bool
  default     = false
}

variable "desktop_image_name" {
  description = "Glance name for the image Terraform downloads and uploads for desktop01"
  type        = string
  default     = "Ubuntu-24.04-desktop-base"
}

variable "desktop_image_url" {
  description = "Cloud image Terraform downloads for desktop01 (the GUI is installed on top of it)"
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "desktop_flavor_name" {
  description = "Flavor for desktop01 (>= 4 GB RAM, >= 20 GB disk recommended); empty = use flavor_name"
  type        = string
  default     = ""
}

variable "desktop_volume_size" {
  description = "Boot volume size in GB for desktop01 (used with zero-disk flavors)"
  type        = number
  default     = 30
}

variable "desktop_upload_image" {
  description = "true = download the Ubuntu cloud image and upload it to Glance; false = use image_name"
  type        = bool
  default     = false
}

variable "vm_volume_size" {
  description = "Boot volume size in GB for vprofile VMs whose flavor has 0 GB disk (e.g. app01 on c2r4)"
  type        = number
  default     = 20
}
