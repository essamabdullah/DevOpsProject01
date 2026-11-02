# desktop01: an XFCE desktop with Firefox, to test the vprofile app from inside the network.
# Set enable_desktop = false in terraform.tfvars to skip all of this.

# Terraform downloads the Ubuntu cloud image and uploads it to Glance.
# Note: "terraform destroy" also deletes this image.
resource "openstack_images_image_v2" "desktop_base" {
  count            = var.enable_desktop ? 1 : 0
  name             = var.desktop_image_name
  image_source_url = var.desktop_image_url
  container_format = "bare"
  disk_format      = "qcow2"
  visibility       = "private"

  properties = {
    os_distro  = "ubuntu"
    os_version = "24.04"
  }
}

# Security group: SSH, RDP and ping from your range (through sshuttle)
resource "openstack_networking_secgroup_v2" "desktop" {
  count       = var.enable_desktop ? 1 : 0
  name        = "${var.name_prefix}-desktop-sg"
  description = "SSH, RDP and ICMP for desktop01"
}

resource "openstack_networking_secgroup_rule_v2" "desktop" {
  for_each = var.enable_desktop ? {
    ssh = { protocol = "tcp", port = 22 }
    rdp = { protocol = "tcp", port = 3389 }
  } : {}
  security_group_id = openstack_networking_secgroup_v2.desktop[0].id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  remote_ip_prefix  = var.ssh_allowed_cidr
}

resource "openstack_networking_secgroup_rule_v2" "desktop_icmp" {
  count             = var.enable_desktop ? 1 : 0
  security_group_id = openstack_networking_secgroup_v2.desktop[0].id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.ssh_allowed_cidr
}

# Port: also in the internal group, so Firefox can reach app01:8080 directly for tests
resource "openstack_networking_port_v2" "desktop" {
  count          = var.enable_desktop ? 1 : 0
  name           = "${var.name_prefix}-desktop01-port"
  network_id     = data.openstack_networking_network_v2.internal.id
  admin_state_up = true
  security_group_ids = [
    openstack_networking_secgroup_v2.internal.id,
    openstack_networking_secgroup_v2.desktop[0].id,
  ]
}

resource "openstack_compute_instance_v2" "desktop" {
  count        = var.enable_desktop ? 1 : 0
  name         = "desktop01"
  image_id     = openstack_images_image_v2.desktop_base[0].id
  flavor_name  = var.desktop_flavor_name != "" ? var.desktop_flavor_name : var.flavor_name
  key_pair     = data.openstack_compute_keypair_v2.key.name
  config_drive = true

  # Boot disk: c2r4 has 0 GB local disk, so boot from a Cinder volume
  block_device {
    uuid                  = local.desktop_image_id
    source_type           = "image"
    destination_type      = "volume"
    volume_size           = var.desktop_volume_size   # the disk size, in GB
    boot_index            = 0
    delete_on_termination = true
  }
  
  # Its own script only; the 5 vprofile VMs keep their user_data unchanged
  user_data = templatefile("${path.module}/scripts/desktop.sh.tftpl", {
    hosts_entries    = local.hosts_entries
    desktop_password = var.ubuntu_password
    dns_servers      = var.dns_servers
  })

  network {
    port = openstack_networking_port_v2.desktop[0].id
  }

  lifecycle {
    # Same reason as the vprofile VMs: adding a VM changes hosts_entries,
    # which would otherwise rebuild desktop01.
    ignore_changes = [user_data]

    precondition {
      condition     = var.ubuntu_password != ""
      error_message = "desktop01 needs ubuntu_password set in terraform.tfvars (used for RDP and console login)."
    }
  }
}

resource "openstack_networking_floatingip_v2" "desktop" {
  count = var.enable_desktop && var.external_network_name != "" ? 1 : 0
  pool  = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "desktop" {
  count       = var.enable_desktop && var.external_network_name != "" ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.desktop[0].address
  port_id     = openstack_networking_port_v2.desktop[0].id
}

# Image for desktop01's boot volume: the uploaded image if enabled, otherwise image_name
data "openstack_images_image_v2" "desktop_existing" {
  count       = var.enable_desktop && !var.desktop_upload_image ? 1 : 0
  name        = var.image_name
  most_recent = true
}

locals {
  desktop_image_id = try(
    openstack_images_image_v2.desktop_base[0].id,
    data.openstack_images_image_v2.desktop_existing[0].id,
    null
  )
}
