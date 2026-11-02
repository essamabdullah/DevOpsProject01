locals {
  web_ip = var.external_network_name == "" ? local.vm_ips["web01"] : openstack_networking_floatingip_v2.fip[0].address
}

output "vm_ips" {
  description = "Internal IPs of all VMs"
  value       = local.vm_ips
}

output "app_url" {
  value = "http://${local.web_ip}"
}

output "ssh_web01" {
  value = "ssh ubuntu@${local.web_ip}"
}

# Backends only accept SSH from inside the internal group, so jump through web01
output "ssh_backends" {
  value = {
    for name, ip in local.vm_ips : name => "ssh -J ubuntu@${local.web_ip} ubuntu@${ip}"
    if name != "web01"
  }
}

locals {
  desktop_ip = !var.enable_desktop ? "" : (
    var.external_network_name == "" ? openstack_networking_port_v2.desktop[0].all_fixed_ips[0] : openstack_networking_floatingip_v2.desktop[0].address
  )
}

output "desktop_rdp" {
  description = "RDP to desktop01 (login: ubuntu / ubuntu_password), then open http://web01 in Firefox"
  value       = var.enable_desktop ? "${local.desktop_ip}:3389" : "desktop disabled"
}

output "ssh_desktop01" {
  value = var.enable_desktop ? "ssh ubuntu@${local.desktop_ip}" : "desktop disabled"
}
