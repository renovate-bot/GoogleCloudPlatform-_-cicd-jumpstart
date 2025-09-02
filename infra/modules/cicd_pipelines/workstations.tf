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

resource "google_project_iam_custom_role" "cws_image_build_runner" {
  count = length(local.workstation_apps) > 0 ? 1 : 0

  project     = data.google_project.project.project_id
  role_id     = "cwsBuildRunner"
  title       = "Cloud Workstation Image Build Runner"
  description = "Terraform managed."
  permissions = [
    "cloudbuild.builds.create",
  ]
}

module "cws_image_build_runner_service_account" {
  count = length(local.workstation_apps) > 0 ? 1 : 0

  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v36.0.1"

  project_id   = data.google_project.project.project_id
  name         = "${local.prefix}ws-image-builder"
  display_name = "Cloud Workstation Image Build Runner Service Account"
  description  = "Terraform-managed."
  iam_sa_roles = {
    (module.service_account_cloud_build.id) : [
      "roles/iam.serviceAccountUser",
    ]
  }
}

resource "google_project_iam_member" "cws_image_build_runner" {
  count = length(local.workstation_apps) > 0 ? 1 : 0

  project = data.google_project.project.project_id
  role    = google_project_iam_custom_role.cws_image_build_runner[0].name
  member  = module.cws_image_build_runner_service_account[0].iam_email
}

# Cloud Scheduler

# cf. https://cloud.google.com/workstations/docs/tutorial-automate-container-image-rebuild
resource "google_cloud_scheduler_job" "cws_image_rebuild" {
  for_each = local.workstation_apps

  project     = data.google_project.project.project_id
  region      = coalesce(each.value.workstation_config.scheduler_region, var.scheduler_default_region)
  name        = "${local.prefix}${each.key}-ws-image-rebuild"
  description = "Terraform-managed."
  schedule    = coalesce(each.value.workstation_config.ci_schedule, var.default_ci_schedule)
  paused      = false
  http_target {
    http_method = "POST"
    uri = format("https://cloudbuild.googleapis.com/v1/projects/%s/locations/%s/triggers/%s:run",
      data.google_project.project.project_id,
      var.cloud_build_region,
      google_cloudbuild_trigger.continuous_integration[each.key].trigger_id
    )
    oauth_token {
      service_account_email = module.cws_image_build_runner_service_account[0].email
    }
  }
}
