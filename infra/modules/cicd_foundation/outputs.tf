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

# go/keep-sorted start block=yes newline_separated=yes
output "cloud_build_trigger_github_connection_needed" {
  description = "Instructions to connect GitHub repository if using GitHub source."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_github_connection_needed : null
}

output "cloud_build_trigger_ids" {
  description = "The full resource IDs of the Cloud Build triggers."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_id : {}
}

output "cloud_build_trigger_trigger_ids" {
  description = "The unique short IDs of the Cloud Build triggers."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].cloud_build_trigger_trigger_id : {}
}

output "secure_source_manager_instance_git_http" {
  description = "The Git HTTP URI of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_git_http : null
}

output "secure_source_manager_instance_git_ssh" {
  description = "The Git SSH URI of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_git_ssh : null
}

output "secure_source_manager_instance_html" {
  description = "The HTML hostname of the created Secure Source Manager instance."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_instance_html : null
}

output "secure_source_manager_repository_git_html" {
  description = "The Git HTML URI of the created Secure Source Manager repository."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_repository_git_html : null
}

output "secure_source_manager_repository_git_https" {
  description = "The Git HTTP URI of the created Secure Source Manager repository."
  value       = length(local.all_apps) > 0 ? module.cicd_pipelines[0].secure_source_manager_repository_git_https : null
}

output "webhook_setup_instructions" {
  description = "Instructions to set up the webhook trigger."
  value = length(local.all_apps) > 0 && var.github_owner == null ? (
    <<-EOT

    Have you configured the Google Auth Platform?
    Visit
    https://console.cloud.google.com/auth/overview/create?project=${data.google_project.project.project_id}
    - App name: cicd-foundation
    - User support email: your-support-email@example.com
    - Audience: internal
    - Contact Information: your-contact-email@example.com
    - Agree to the User Data Policy

    To avoid issues with Application Default Credentials, set the quota project by running:
    gcloud auth application-default set-quota-project ${data.google_project.project.project_id}

%{if module.cicd_pipelines[0].secure_source_manager_instance_html != null~}
    For each custom image open
    https://${module.cicd_pipelines[0].secure_source_manager_instance_html}/${data.google_project.project.project_id}/${module.cicd_pipelines[0].secure_source_manager_repository_name}/settings/hooks/gitea/new
%{endif~}
    Follow the instructions from
    https://cloud.google.com/secure-source-manager/docs/set-up-webhooks#set-up-webhook
    to setup a webhook(s) using the following information:
    ${join("\n", [for image, id in module.cicd_pipelines[0].cloud_build_trigger_id : (
    <<-IMAGE_INFO
    - Hook ID: ${image}
      - Target URL:
        https://cloudbuild.googleapis.com/v1/${id}:webhook
      - Sensitive Query String:
        key=${module.cicd_pipelines[0].cloud_build_api_key}&secret=${module.cicd_pipelines[0].webhook_trigger_secret_key}&trigger=${module.cicd_pipelines[0].cloud_build_trigger_trigger_id[image]}&projectId=${data.google_project.project.project_id}
    IMAGE_INFO
)])}
    Optional: *Git Refs filter for Push Events*: restrict the glob expression for the git refs filter, e.g., to `main`
    EOT
) : null
sensitive = true
}

output "webhook_setup_instructions_display" {
  description = "Instructions to set up the webhook trigger."
  value = length(local.all_apps) > 0 && var.github_owner == null ? (
    <<-EOT

    To output the instructions (with sensitive information) to set up the
    webhook trigger, run:
    terraform output webhook_setup_instructions
    EOT
  ) : null
}
# go/keep-sorted end
