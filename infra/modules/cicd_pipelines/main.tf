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
  # go/keep-sorted start
  activate_apis = concat([
    "secretmanager.googleapis.com",
    "securesourcemanager.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudkms.googleapis.com",
    "artifactregistry.googleapis.com",
    "containeranalysis.googleapis.com",
    "containerscanning.googleapis.com",
    "ondemandscanning.googleapis.com",
    "binaryauthorization.googleapis.com",
    "clouddeploy.googleapis.com",
    ],
    length(local.workstation_apps) > 0 ? ["cloudscheduler.googleapis.com"] : []
  )
  artifact_registry_project_id = data.google_project.project.project_id
  artifact_registry_repository_uri = format(
    "%s-docker.pkg.dev/%s/%s",
    data.google_artifact_registry_repository.container_repository.location,
    local.artifact_registry_project_id,
    data.google_artifact_registry_repository.container_repository.repository_id
  )
  build_project_id                = data.google_project.project.project_id
  cloud_deploy_apps               = { for key, value in var.apps : key => value if contains(local.cloud_deploy_supported_runtimes, value.runtime) }
  cloud_deploy_supported_runtimes = ["cloudrun", "gke"]
  github_source                   = var.github_owner != null && var.github_repo != null
  kms_project_id                  = data.google_project.project.project_id
  prefix                          = var.namespace == "" ? "" : "${var.namespace}-"
  workstation_apps                = { for k, v in var.apps : k => v if v.runtime == "workstations" }
  # go/keep-sorted end
}

data "google_project" "project" {
  project_id = var.project_id

  depends_on = [
    module.project_services
  ]
}

module "project_services_cloud_resourcemanager" {
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
  activate_apis               = local.activate_apis

  depends_on = [
    module.project_services_cloud_resourcemanager
  ]
}
