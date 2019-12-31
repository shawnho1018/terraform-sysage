provider "vsphere" {
  user = "${var.vsphere_user}"
  password = "${var.vsphere_password}"
  vsphere_server = "${var.vsphere_server}"
  # If you have a self-signed cert
  allow_unverified_ssl = true
}
module "virtual-machine" {
  source  = "ulm0/vms/vsphere"
  version = "0.12.0"
  # Parameters for vSphere submodule
  vs_dc_name                 = "SDDC-SYS"
  vs_ds_name                 = "vsanDatastore"
  vs_cluster_name            = "syspks"
  vs_vm_folder               = "ClusterAPI"
  vs_rp_name                 = "VCS"
  vs_network_name            = "PG-MGMT"
  vm_template_name           = "ubuntu1804"
  
  dns_servers                = ["10.9.25.31"]
  domain                     = "syspks.com"
  vm_cpus                    = "2"
  vm_mem                     = "2048"
  vm_disk_size               = "60"
  vms                        = {"vm-1" = "10.9.25.70"}
  ip_netmask                 = "25"
  ip_gateway                 = "10.9.25.126"
}