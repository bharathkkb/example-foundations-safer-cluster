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

# FW rule to allow ingress to frontend
resource "google_compute_firewall" "elb-http-fw" {
  name          = "elb-http-fw"
  network       = var.network_name
  project       = var.network_project_id
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  enable_logging          = true
  target_service_accounts = [module.gke.service_account]
}

module "gke" {
  source  = "terraform-google-modules/kubernetes-engine/google//modules/safer-cluster"
  version = "~>11.1.0"

  project_id                 = module.enabled_google_apis.project_id
  name                       = var.cluster_name
  region                     = var.region
  network                    = var.network_name
  network_project_id         = var.network_project_id
  add_cluster_firewall_rules = true
  subnetwork                 = var.subnet_name
  ip_range_pods              = var.ip_range_pods_name
  ip_range_services          = var.ip_range_services_name
  master_ipv4_cidr_block     = var.master_ipv4_cidr_block
  enable_private_endpoint    = true
  master_authorized_networks = [{
    cidr_block   = "${module.bastion.ip_address}/32"
    display_name = "Bastion Host"
  }]
  grant_registry_access = true
  # allow-google-apis tag allows GKE nodes egress to private.googleapis.com
  # allow-lb tag allows ingress for loadbalancer health checks
  # more info about these tags can be found here: https://github.com/terraform-google-modules/terraform-example-foundation#3-networks
  node_pools_tags = {
    all = ["allow-google-apis", "allow-lb"]
  }
  node_pools = [
    {
      name         = "safer-pool"
      min_count    = 1
      max_count    = 4
      auto_upgrade = true
    }
  ]
}
