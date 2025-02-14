provider "google" {
  version = "~> 2.0"
}

# Used to determine your public IP for forwarding rules
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

locals {
  cluster_name = "addinst-dcos-ee-demo"
}

module "dcos" {
  source  = "dcos-terraform/dcos/gcp"
  version = "~> 0.2.0"

  providers = {
    google = "google"
  }

  cluster_name        = "${local.cluster_name}"
  ssh_public_key_file = "~/.ssh/id_rsa.pub"
  admin_ips           = ["${data.http.whatismyip.body}/32"]

  num_masters        = "1"
  num_private_agents = "1"
  num_public_agents  = "1"

  dcos_instance_os       = "centos_7"
  bootstrap_machine_type = "n1-standard-4"

  dcos_variant              = "ee"
  dcos_version              = "1.12.3"
  dcos_license_key_contents = "${file("~/license.txt")}"

  # provide a SHA512 hashed password, here "deleteme"
  dcos_superuser_password_hash = "$6$rounds=656000$YSvuFmasQDXheddh$TpYlCxNHF6PbsGkjlK99Pwxg7D0mgWJ.y0hE2JKoa61wHx.1wtxTAHVRHfsJU9zzHWDoE08wpdtToHimNR9FJ/"
  dcos_superuser_username      = "demo-super"

  dcos_config = <<EOF
feature_dcos_storage_enabled: true
EOF

  additional_private_agent_ips = ["${module.addinst.private_ips}"]
}

module "addinst" {
  source  = "dcos-terraform/private-agents/gcp"
  version = "~> 0.2.0"

  cluster_name                  = "${local.cluster_name}"
  hostname_format               = "%[3]s-addinstpriv%[1]d-%[2]s"
  private_agent_subnetwork_name = "${module.dcos.infrastructure.private_agents.subnetwork_name}"
  ssh_user                      = "${module.dcos.infrastructure.private_agents.os_user}"
  machine_type                  = "n1-standard-8"
  disk_size                     = 240
  dcos_version                  = "1.12.3"
  image                         = "centos-7"
  disk_type                     = "pd-ssd"
  public_ssh_key                = "~/.ssh/id_rsa.pub"
  zone_list                     = "${module.dcos.infrastructure.private_agents.zone_list}"

  num_private_agents = "2"
}

output "masters_dns_name" {
  description = "This is the load balancer address to access the DC/OS UI"
  value       = "${module.dcos.masters-loadbalancer}"
}
