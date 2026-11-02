os_cloud              = "openstack"
image_name            = "Ubuntu 24.04 LTS (old-20260712)"
flavor_name           = "e1.small"
app_flavor_name       = "c2r4"                   # set a bigger flavor (>= 2 GB RAM) for app01 if "small" is less
network_name          = "internal"
key_pair_name         = "n-keypair"
external_network_name = ""
#ssh_allowed_cidr      = "0.0.0.0/0"          # narrow to your IP, e.g. "41.x.x.x/32"

# Provision one VM at a time; empty list = all five
vm_names = ["web01","db01","mc01","rmq01","app01"]

# Console / RDP password for the ubuntu user (required for desktop01)
ubuntu_password = "ubuntu"

# DNS forced inside the VMs; set [] if you fixed DNS on the subnet instead
dns_servers = ["8.8.8.8"]

# Test desktop with GUI + Firefox
enable_desktop      = true
desktop_flavor_name = "c2r4"                     # >= 4 GB RAM / 20 GB disk recommended
desktop_volume_size = 30

# Application credentials (same as the PDF)
db_root_password = "admin123"
db_password      = "admin123"
rmq_password     = "test"
