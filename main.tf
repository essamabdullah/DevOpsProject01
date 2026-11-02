# Existing internal network, looked up by name
data "openstack_networking_network_v2" "internal" {
  name = var.network_name
}

# Existing keypair, looked up by name
data "openstack_compute_keypair_v2" "key" {
  name = var.key_pair_name
}

# Look up the image once, so boot volumes can be created from it
data "openstack_images_image_v2" "vm" {
  name        = var.image_name
  most_recent = true
}

# Look up every flavor in use, to see which ones have 0 GB disk
data "openstack_compute_flavor_v2" "vm" {
  for_each = toset(values(local.vm_flavor))
  name     = each.value
}

locals {
  # The 5 VMs from the PDF, in its setup order
  all_vms = {
    db01  = { script = "mysql.sh.tftpl" }
    mc01  = { script = "memcache.sh.tftpl" }
    rmq01 = { script = "rabbitmq.sh.tftpl" }
    app01 = { script = "tomcat.sh.tftpl" }
    web01 = { script = "nginx.sh.tftpl" }
  }

  # Only the VMs listed in var.vm_names (all five when the list is empty)
  vms = length(var.vm_names) == 0 ? local.all_vms : {
    for name, vm in local.all_vms : name => vm if contains(var.vm_names, name)
  }

  # Floating IP only when an external network is set AND web01 is being created
  create_fip = var.external_network_name != "" && contains(keys(local.vms), "web01")

  app_flavor = var.app_flavor_name != "" ? var.app_flavor_name : var.flavor_name

  # Which flavor each VM uses, and whether that flavor needs a boot volume
  vm_flavor      = { for name, _ in local.vms : name => (name == "app01" ? local.app_flavor : var.flavor_name) }
  vm_from_volume = { for name, f in local.vm_flavor : name => data.openstack_compute_flavor_v2.vm[f].disk == 0 }
  
  # Replaces vagrant-hostmanager: IPs come from the ports (assigned by DHCP),
  # and the same /etc/hosts block is written on every VM.
  vm_ips        = { for name, p in openstack_networking_port_v2.port : name => p.all_fixed_ips[0] }
  hosts_entries = join("\n", [for name, ip in local.vm_ips : "${ip} ${name}"])

  # Values for scripts/common.sh.tftpl (used by every VM, including desktop01)
  common_vars = {
    hosts_entries   = local.hosts_entries
    ubuntu_password = var.ubuntu_password
    dns_servers     = var.dns_servers
  }

  script_vars = {
    repo_url         = var.repo_url
    repo_branch      = var.repo_branch
    db_root_password = var.db_root_password
    db_user          = var.db_user
    db_password      = var.db_password
    rmq_user         = var.rmq_user
    rmq_password     = var.rmq_password
    tomcat_version   = var.tomcat_version
    java_version     = var.java_version
  }
}

# One port per VM on the internal network, with its security groups attached.
# Ports are created before the VMs, so every VM knows all IPs at boot.
resource "openstack_networking_port_v2" "port" {
  for_each       = local.vms
  name           = "${var.name_prefix}-${each.key}-port"
  network_id     = data.openstack_networking_network_v2.internal.id
  admin_state_up = true

  security_group_ids = each.key == "web01" ? [
    openstack_networking_secgroup_v2.internal.id,
    openstack_networking_secgroup_v2.web.id,
  ] : [openstack_networking_secgroup_v2.internal.id]
}

# The instances
resource "openstack_compute_instance_v2" "vm" {
  for_each     = local.vms
  name         = each.key
  flavor_name  = local.vm_flavor[each.key]
  key_pair     = data.openstack_compute_keypair_v2.key.name
  config_drive = true # metadata via attached disk; the metadata service is not reachable

  # Flavors with a local disk boot from the image directly
  image_name = local.vm_from_volume[each.key] ? null : var.image_name

  # Zero-disk flavors (like c2r4) boot from a Cinder volume instead
  dynamic "block_device" {
    for_each = local.vm_from_volume[each.key] ? [1] : []
    content {
      uuid                  = data.openstack_images_image_v2.vm.id
      source_type           = "image"
      destination_type      = "volume"
      volume_size           = var.vm_volume_size
      boot_index            = 0
      delete_on_termination = true
    }
  }

  # cloud-init runs this on first boot: common part + the service script
  user_data = join("\n", [
    templatefile("${path.module}/scripts/common.sh.tftpl", local.common_vars),
    templatefile("${path.module}/scripts/${each.value.script}", local.script_vars),
  ])

  network {
    port = openstack_networking_port_v2.port[each.key].id
  }

  lifecycle {
    ignore_changes = [user_data]
  }
}

# Optional floating IP for web01 only
resource "openstack_networking_floatingip_v2" "fip" {
  count = local.create_fip ? 1 : 0
  pool  = var.external_network_name
}

resource "openstack_networking_floatingip_associate_v2" "fip_assoc" {
  count       = local.create_fip ? 1 : 0
  floating_ip = openstack_networking_floatingip_v2.fip[0].address
  port_id     = openstack_networking_port_v2.port["web01"].id
}
