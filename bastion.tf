/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  bastion_name = format("%s-bastion", var.cluster_name)
  bastion_zone = format("%s-a", var.region)
}

data "template_file" "startup_script" {
  template = <<-EOF
  sudo apt-get update -y
  sudo apt-get install -y tinyproxy
  EOF
}

data "google_compute_subnetwork" "subnetwork" {
  name    = var.subnet_name
  project = var.network_project_id
  region  = var.region
}

# FW rule for bastion tinyproxy package
resource "google_compute_firewall" "bastion-fw" {
  name      = "bastion-egress-fw"
  network   = var.network_name
  project   = var.network_project_id
  direction = "EGRESS"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  target_service_accounts = [module.bastion.service_account]
}

module "bastion" {
  source         = "terraform-google-modules/bastion-host/google"
  version        = "~> 2.0"
  network        = var.network_name
  subnet         = data.google_compute_subnetwork.subnetwork.self_link
  project        = module.enabled_google_apis.project_id
  host_project   = var.network_project_id
  name           = local.bastion_name
  zone           = local.bastion_zone
  image_project  = "debian-cloud"
  image_family   = "debian-9"
  machine_type   = "g1-small"
  startup_script = data.template_file.startup_script.rendered
  members        = var.bastion_members
  shielded_vm    = "false"
  # allow-iap-ssh tag allows SSH via IAP
  # egress-internet is a tag based route through IGW to access internet
  tags           = ["allow-iap-ssh", "egress-internet"]
}
