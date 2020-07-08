provider "nsxt" {
#  version              = "~> 1.1"
  host                 = "10.50.113.60"
  username             = "admin"
  password             = "VMware1!VMware1!"
  allow_unverified_ssl = true
  max_retries = 10
  retry_min_delay = 500
  retry_max_delay = 5000
  retry_on_status_codes = [429]
}

variable "nsx_tag_scope" {
  default = "project"
}

variable "nsx_tag" {
  default = "terraform-demo"
}

resource "nsxt_policy_group" "all_vms" {
  display_name = "All_VMs"
  description  = "Group consisting of ALL VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = var.nsx_tag

    }
  }
}

resource "nsxt_policy_group" "web_group" {
  display_name = "Web_VMs"
  description  = "Group consisting of Web VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "web"
    }
  }
  tag {
    scope = var.nsx_tag_scope
    tag   = var.nsx_tag
  }
}

resource "nsxt_policy_group" "app_group" {
  display_name = "App_VMs"
  description  = "Group consisting of App VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "app"
    }
  }
  tag {
    scope = var.nsx_tag_scope
    tag   = var.nsx_tag
  }
}

resource "nsxt_policy_group" "db_group" {
  display_name = "DB_VMs"
  description  = "Group consisting of DB VMs"
  criteria {
    condition {
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      key         = "Tag"
      value       = "db"
    }
  }
  tag {
    scope = var.nsx_tag_scope
    tag   = var.nsx_tag
  }
}

resource "nsxt_policy_service" "app_service" {
  display_name = "app_service_8443"
  description  = "Service for App that listens on port 8443"
  l4_port_set_entry {
    description       = "TCP Port 8443"
    protocol          = "TCP"
    destination_ports = ["8443"]
  }
  tag {
    scope = var.nsx_tag_scope
    tag   = var.nsx_tag
  }
}

data "nsxt_policy_service" "https" {
  display_name = "HTTPS"
}

data "nsxt_policy_service" "mysql" {
  display_name = "MySQL"
}

data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

resource "nsxt_policy_security_policy" "firewall_section" {
  display_name = "DFW Section"
  description  = "Firewall section created by Terraform"
  scope        = [nsxt_policy_group.all_vms.path]
  category     = "Application"
  locked       = "false"
  stateful     = "true"

  tag {
    scope = var.nsx_tag_scope
    tag   = var.nsx_tag
  }

  # Allow communication to any VMs only on the ports defined earlier
  rule {
    display_name       = "Allow HTTPS"
    description        = "In going rule"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.web_group.path]
    services           = [data.nsxt_policy_service.https.path]
  }

  rule {
    display_name       = "Allow SSH"
    description        = "In going rule"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    destination_groups = [nsxt_policy_group.web_group.path]
    services           = [data.nsxt_policy_service.ssh.path]
  }

  # Web to App communication
  rule {
    display_name       = "Allow Web to App"
    description        = "Web to App communication"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    source_groups      = [nsxt_policy_group.web_group.path]
    destination_groups = [nsxt_policy_group.app_group.path]
    services           = [nsxt_policy_service.app_service.path]
  }

  # App to DB communication
  rule {
    display_name       = "Allow App to DB"
    description        = "App to DB communication"
    action             = "ALLOW"
    logged             = "false"
    ip_version         = "IPV4"
    source_groups      = [nsxt_policy_group.app_group.path]
    destination_groups = [nsxt_policy_group.db_group.path]
    services           = [data.nsxt_policy_service.mysql.path]
  }

  # Allow VMs to communicate with outside
  rule {
    display_name  = "Allow out"
    description   = "Outgoing rule"
    action        = "ALLOW"
    logged        = "true"
    ip_version    = "IPV4"
    source_groups = [nsxt_policy_group.all_vms.path]
  }

  # Reject everything else
  rule {
    display_name = "Deny ANY"
    description  = "Default Deny the traffic"
    action       = "REJECT"
    logged       = "true"
    ip_version   = "IPV4"
  }
}