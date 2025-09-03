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

module "cws_service_account" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v40.1.0"

  project_id   = data.google_project.project.project_id
  name         = var.cws_service_account_name
  display_name = "Cloud Workstation Service Account"
  description  = "Terraform-managed."
}

resource "google_project_iam_member" "workstations_operation_viewer" {
  # grant to all users listed in the `creators` field of each Cloud Workstations configuration
  for_each = toset(flatten([for config in var.cws_configs : coalesce(config.creators, [])]))

  project = data.google_project.project.project_id
  role    = "roles/workstations.operationViewer"
  member  = "user:${each.key}"
}
