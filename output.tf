
output "public_ip" {
  value = "${nsxt_lb_http_virtual_server.lb_virtual_server.ip_address}"
}

output "instance_url" {
  value = "http://${nsxt_lb_http_virtual_server.lb_virtual_server.ip_address}:${nsxt_lb_http_virtual_server.lb_virtual_server.port}"
}
