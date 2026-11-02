# Replaces all the firewalld steps in the PDF.

locals {
  # Backend ports, open only between VMs that are in the vprofile-internal group
  internal_ports = {
    ssh          = { port = 22, protocol = "tcp" }
    mysql        = { port = 3306, protocol = "tcp" }
    memcache     = { port = 11211, protocol = "tcp" }
    memcache_udp = { port = 11111, protocol = "udp" }
    rabbitmq     = { port = 5672, protocol = "tcp" }
    tomcat       = { port = 8080, protocol = "tcp" }
  }
}

# ---- Internal group: attached to all 5 VMs ----
resource "openstack_networking_secgroup_v2" "internal" {
  name        = "${var.name_prefix}-internal-sg"
  description = "Backend traffic between vprofile VMs"
}

resource "openstack_networking_secgroup_rule_v2" "internal" {
  for_each          = local.internal_ports
  security_group_id = openstack_networking_secgroup_v2.internal.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port
  port_range_max    = each.value.port
  # Only members of this same group may connect, so no subnet CIDR is needed
  remote_group_id = openstack_networking_secgroup_v2.internal.id
}

resource "openstack_networking_secgroup_rule_v2" "internal_icmp" {
  security_group_id = openstack_networking_secgroup_v2.internal.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_group_id   = openstack_networking_secgroup_v2.internal.id
}

# ---- Web group: attached to web01 only (same rules as your test-vm1) ----
resource "openstack_networking_secgroup_v2" "web" {
  name        = "${var.name_prefix}-web-sg"
  description = "SSH, ICMP and HTTP for web01"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.ssh_allowed_cidr
}

resource "openstack_networking_secgroup_rule_v2" "icmp" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "icmp"
  remote_ip_prefix  = var.ssh_allowed_cidr
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  security_group_id = openstack_networking_secgroup_v2.web.id
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.http_allowed_cidr
}
