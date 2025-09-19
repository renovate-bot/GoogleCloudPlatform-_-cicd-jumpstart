# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  images       = keys(var.cws_custom_images)
  target_names = keys(var.android_targets)

  # Generate all combinations of config, image, branch, and target
  cws_combinations = flatten([
    for config_key, config_value in var.cws_configs : [
      for item in setproduct(local.images, var.android_branches, local.target_names) :
      {
        config_key   = config_key
        config_value = config_value
        image        = item[0]
        branch       = item[1]
        target       = item[2]
      }
    ]
  ])

  # Build the cws_configs_product map from the combinations
  cws_configs_product = {
    for combo in local.cws_combinations :
    "${combo.config_key}-${lower(combo.image)}-${lower(combo.branch)}-${lower(combo.target)}" => merge(
      combo.config_value,
      {
        image = lower(combo.image)
        instances = [for i in try(combo.config_value.instances, []) : {
          # The 'name' is constructed to be unique and descriptive within GCP's resource naming limits (63 characters).
          # It combines elements reflecting the instance name, image, branch, and target from the combination.
          # A short SHA256 hash of the full display name is appended to ensure uniqueness.
          name = join("-", [
            lower(substr(i.name, 0, 20)),
            lower(substr(join("-", [for part in split("-", combo.image) : substr(part, 0, 4)]), 0, 11)),
            lower(substr(join("-", [for part in split("-", combo.branch) : substr(part, 0, 4)]), 0, 11)),
            lower(substr(join("-", [for part in split("-", combo.target) : substr(part, 0, 4)]), 0, 11)),
            substr(sha256("${i.name}-${combo.image}-${combo.branch}-${combo.target}"), 0, 4)
          ])
          display_name = "${i.name}-${combo.image}-${combo.branch}-${combo.target}"
          users        = i.users
        }]
      }
    )
  }
}

data "google_project" "project" {
  project_id = var.project_id

  depends_on = [
    module.project_services
  ]
}

module "project_services_cloud_resource_manager" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "18.0.0"

  project_id                  = var.project_id
  enable_apis                 = var.enable_apis
  disable_services_on_destroy = false
  activate_apis = [
    "cloudresourcemanager.googleapis.com"
  ]
}

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "18.0.0"

  project_id                  = var.project_id
  enable_apis                 = var.enable_apis
  disable_services_on_destroy = false
  activate_apis = [
    "compute.googleapis.com",
    "monitoring.googleapis.com",
    "servicenetworking.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  depends_on = [
    module.project_services_cloud_resource_manager
  ]
}
