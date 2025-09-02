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

# Source Control (Secure Source Manager)

# go/keep-sorted start block=yes newline_separated=yes
output "secure_source_manager_instance_git_http" {
  description = "The Git HTTP URI of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].git_http
}

output "secure_source_manager_instance_git_ssh" {
  description = "The Git SSH URI of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].git_ssh
}

output "secure_source_manager_instance_html" {
  description = "The HTML hostname of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].html
}

output "secure_source_manager_instance_id" {
  description = "The ID of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.id
}
# go/keep-sorted end

# Cloud Build

# go/keep-sorted start block=yes newline_separated=yes
output "cloud_build_service_account_email" {
  description = "The email of the Cloud Build service account."
  value       = module.service_account_cloud_build.email
}

output "cloud_build_service_account_id" {
  description = "The ID of the Cloud Build service account."
  value       = module.service_account_cloud_build.id
}

output "cloud_build_trigger_github_connection_needed" {
  description = "Instructions to connect GitHub repository if using GitHub source."
  value = local.github_source ? (<<-EOT
    you first need to connect the GitHub repository to your GCP project:
    https://console.cloud.google.com/cloud-build/triggers;region=global/connect
    before you can create this trigger
  EOT
  ) : ""
}

output "cloud_build_trigger_id" {
  description = "The full resource ID of the Cloud Build trigger."
  value       = { for k, v in google_cloudbuild_trigger.continuous_integration : k => v.id }
}

output "cloud_build_trigger_trigger_id" {
  description = "The unique short ID of the Cloud Build trigger."
  value       = { for k, v in google_cloudbuild_trigger.continuous_integration : k => v.trigger_id }
}

output "cloud_build_worker_pool_ids" {
  description = "A map of Cloud Build Worker Pool IDs, keyed by stage name."
  value       = { for k, v in google_cloudbuild_worker_pool.pool : k => v.id }
}
# go/keep-sorted end

# Binary Authorization

# go/keep-sorted start block=yes newline_separated=yes
output "binary_authorization_policy_id" {
  description = "The ID of the created Binary Authorization Policy."
  value       = google_binary_authorization_policy.policy.id
}
# go/keep-sorted end

# Artifact Registry

# go/keep-sorted start block=yes newline_separated=yes
output "artifact_registry_repository" {
  description = "The Artifact Registry repository object."
  value       = data.google_artifact_registry_repository.container_repository
}

output "artifact_registry_repository_uri" {
  description = "The URI of the Artifact Registry repository."
  value       = local.artifact_registry_repository_uri
}
# go/keep-sorted end
