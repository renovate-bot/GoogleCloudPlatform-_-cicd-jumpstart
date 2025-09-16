# Copyright 2023-2025 Google LLC
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
  cloud_build_region        = var.region
  secret_manager_region     = var.region
  cws_apps = {
    for k, v in var.cws_custom_images : k => {
      runtime = "workstations"
      build = {
        dockerfile_path = try(v.build.dockerfile_path, null)
        timeout_seconds = try(v.build.timeout_seconds, null)
        machine_type    = try(v.build.machine_type, null)
      }
      workstation_config = {
        scheduler_region = try(v.workstation_config.scheduler_region, null)
        ci_schedule      = try(v.workstation_config.ci_schedule, null)
      }
    }
  }
}

module "workstations" {
  source = "github.com/GoogleCloudPlatform/cicd-foundation//infra/modules/cicd_workstations?ref=v3.0.0"

  project_id   = data.google_project.project.project_id
  enable_apis  = var.enable_apis
  cws_clusters = var.cws_clusters
  cws_configs  = local.cws_configs_product
}

module "cicd_pipelines" {
  count = length(var.cws_custom_images) > 0 ? 1 : 0

  source = "github.com/GoogleCloudPlatform/cicd-foundation//infra/modules/cicd_pipelines?ref=v3.0.0"

  project_id = data.google_project.project.project_id
  enable_apis = var.enable_apis
  # go/keep-sorted start
  apps                                = local.cws_apps
  artifact_registry_id                = google_artifact_registry_repository.container_registry.repository_id
  artifact_registry_readers = [
    "serviceAccount:${module.workstations.cws_service_account_email}"
  ]
  artifact_registry_region            = google_artifact_registry_repository.container_registry.location
  cloud_build_region                  = local.cloud_build_region
  git_branch_trigger                  = var.git_branch_trigger
  git_branches_regexp_trigger         = var.git_branches_regexp_trigger
  github_owner                        = var.github_owner
  github_repo                         = var.github_repo
  secret_manager_region               = local.secret_manager_region
  secure_source_manager_instance_name = var.secure_source_manager_instance_name
  secure_source_manager_region        = var.secure_source_manager_region
  # go/keep-sorted end
}
