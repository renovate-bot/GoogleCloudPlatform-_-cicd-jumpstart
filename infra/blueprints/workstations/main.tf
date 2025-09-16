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

  artifact_registry_repository_uri = format(
    "%s-docker.pkg.dev/%s/%s",
    google_artifact_registry_repository.container_registry.location,
    google_artifact_registry_repository.container_registry.project,
    google_artifact_registry_repository.container_registry.repository_id
  )

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
        image = "${local.artifact_registry_repository_uri}/${lower(combo.image)}:latest"
        instances = [
          {
            # Generate a short, unique name for each workstation instance based on the combination.
            # This involves splitting the config key, image, branch, and target by '-',
            # taking the first 4 characters of each part, joining them with '-',
            # and then truncating the result to a maximum of 12 characters.
            name = join("-", [
              lower(substr(join("-", [for part in split("-", combo.config_key) : substr(part, 0, 4)]), 0, 12)),
              lower(substr(join("-", [for part in split("-", combo.image) : substr(part, 0, 4)]), 0, 12)),
              lower(substr(join("-", [for part in split("-", combo.branch) : substr(part, 0, 4)]), 0, 12)),
              lower(substr(join("-", [for part in split("-", combo.target) : substr(part, 0, 4)]), 0, 12)),
              substr(sha256("${combo.config_key}-${combo.image}-${combo.branch}-${combo.target}"), 0, 4)
            ])

            display_name = "${combo.config_key}-${combo.image}-${combo.branch}-${combo.target}"

            # The 'users' field is populated by flattening the 'users' lists from each instance
            # defined within 'combo.config_value.instances'. These users are assumed to be the
            # creators of the workstation instances. Defaults to an empty list if
            # 'combo.config_value.instances' is null or empty.
            users = (
              combo.config_value.instances == null ?
              [] :
              flatten([
                for instance in combo.config_value.instances : instance.users
              ])
            )
          }
        ]
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
