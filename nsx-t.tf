provider "nsxt" {
  host                     = "${var.nsxt_server}"
  username                 = "${var.nsxt_user}"
  password                 = "${var.nsxt_password}"
  allow_unverified_ssl     = true
  max_retries              = 10
  retry_min_delay          = 500
  retry_max_delay          = 5000
  retry_on_status_codes    = [429]
}

data "nsxt_edge_cluster" "edge_cluster1" {
  display_name = "${var.nsxt_edgecluster}"
}
data "nsxt_logical_tier0_router" "tier0_router" {
  display_name = "${var.nsxt_t0}"
}
data "nsxt_transport_zone" "overlay_transport_zone" {
  display_name = "${var.nsxt_tz_overlay}"
}

resource "nsxt_ip_pool" "ip_pool" {
  description = "terraform-pool"
  display_name = "terraform_ip_pool"
  tag {
    scope = "color"
    tag   = "red"
  }
  subnet {
    cidr              = "192.168.2.0/24"
    allocation_ranges = ["192.168.2.2-192.168.2.254"]
    gateway_ip        = "192.168.2.1"
    dns_suffix        = "syspks.com"
    dns_nameservers   = ["10.9.25.31"]
  }
}
resource "nsxt_logical_switch" "switch1" {
  admin_state       = "UP"
  description       = "LS1 provisioned by Terraform"
  display_name      = "LS1"
  transport_zone_id = "${data.nsxt_transport_zone.overlay_transport_zone.id}"
  replication_mode  = "MTEP"

  # Get Subnet from IP-Pool
  ip_pool_id = "${nsxt_ip_pool.ip_pool.id}"
}
resource "nsxt_logical_tier1_router" "tier1_router" {
  description                 = "RTR1 provisioned by Terraform"
  display_name                = "RTR1"
  failover_mode               = "NON_PREEMPTIVE"
  edge_cluster_id             = "${data.nsxt_edge_cluster.edge_cluster1.id}"
  enable_router_advertisement = true
  advertise_connected_routes  = true
  advertise_static_routes     = true
  advertise_nat_routes        = true
  advertise_lb_vip_routes     = true
  advertise_lb_snat_ip_routes = false

}
resource "nsxt_logical_router_link_port_on_tier0" "link_port_T0" {
  description       = "TIER0_PORT1 provisioned by Terraform"
  display_name      = "T0_PORT1_forRTR1"
  logical_router_id = "${data.nsxt_logical_tier0_router.tier0_router.id}"

}
resource "nsxt_logical_router_link_port_on_tier1" "link_port_T1" {
  description                   = "TIER1_PORT1 provisioned by Terraform"
  display_name                  = "TIER1_PORT1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_router_port_id = "${nsxt_logical_router_link_port_on_tier0.link_port_T0.id}"

}
resource "nsxt_logical_port" "logical_port" {
  admin_state       = "UP"
  description       = "LP1 provisioned by Terraform"
  display_name      = "LP1"
  logical_switch_id = "${nsxt_logical_switch.switch1.id}"

}
resource "nsxt_logical_router_downlink_port" "downlink_port" {
  description                   = "DP1 provisioned by Terraform"
  display_name                  = "DP1"
  logical_router_id             = "${nsxt_logical_tier1_router.tier1_router.id}"
  linked_logical_switch_port_id = "${nsxt_logical_port.logical_port.id}"
  ip_address                    = "192.168.2.1/24"

}
# Load Balancer
resource "nsxt_lb_service" "lb_service" {
  description  = "lb_service provisioned by Terraform"
  display_name = "lb_service"

  enabled           = true
  logical_router_id = "${nsxt_logical_tier1_router.tier1_router.id}"
  error_log_level   = "INFO"
  size              = "SMALL"
  depends_on        = ["nsxt_logical_router_link_port_on_tier1.link_port_T1"]
  virtual_server_ids = ["${nsxt_lb_http_virtual_server.lb_virtual_server.id}"]
}

# Add Pool Members
resource "nsxt_lb_pool" "dynamic_pool" {
  description              = "lb_pool provisioned by Terraform"
  display_name             = "dynamic_lb_pool"
  algorithm                = "LEAST_CONNECTION"
  min_active_members       = 1
  tcp_multiplexing_enabled = false
  tcp_multiplexing_number  = 3

  snat_translation {
    type          = "SNAT_AUTO_MAP"
  }

  member {
    admin_state                = "ENABLED"
    backup_member              = "false"
    display_name               = "1st-member"
    ip_address                 = "192.168.2.2"
    max_concurrent_connections = "1"
    port                       = "8080"
    weight                     = "1"
  }
  member {
    admin_state                = "ENABLED"
    backup_member              = "false"
    display_name               = "2nd-member"
    ip_address                 = "192.168.2.3"
    max_concurrent_connections = "1"
    port                       = "8080"
    weight                     = "1"
  }  
}
# Set Virtual Service
resource "nsxt_lb_http_virtual_server" "lb_virtual_server" {
  description                = "lb_virtual_server provisioned by terraform"
  display_name               = "virtual server 1"
  access_log_enabled         = true
  enabled                    = true
  ip_address                 = "10.9.25.250"
  port                       = "80"
  default_pool_member_port   = "80"
  max_concurrent_connections = 50
  max_new_connection_rate    = 20
  application_profile_id     = "${nsxt_lb_http_application_profile.http_xff.id}"
  #persistence_profile_id     = "${nsxt_lb_cookie_persistence_profile.session_persistence.id}"
  pool_id                    = "${nsxt_lb_pool.dynamic_pool.id}"
  #sorry_pool_id              = "${nsxt_lb_pool.sorry_pool.id}"
  #rule_ids                   = ["${nsxt_lb_http_request_rewrite_rule.redirect_post.id}"]
}
resource "nsxt_lb_http_application_profile" "http_xff" {
  description            = "lb_http_application_profile provisioned by Terraform"
  display_name           = "lb_http_application_profile"
  http_redirect_to_https = "false"
  ntlm                   = "true"
  x_forwarded_for        = "INSERT"
}