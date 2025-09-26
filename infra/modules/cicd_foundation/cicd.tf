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

module "cicd_pipelines" {
  count = length(local.all_apps) > 0 ? 1 : 0

  source = "./cicd_pipelines"

  project_id  = data.google_project.project.project_id
  enable_apis = var.enable_apis
  # go/keep-sorted start
  apps                                        = local.all_apps
  artifact_registry_id                        = var.artifact_registry_id
  artifact_registry_region                    = var.artifact_registry_region
  cloud_build_api_key_display_name            = var.cloud_build_api_key_display_name
  cloud_build_api_key_name                    = var.cloud_build_api_key_name
  cloud_build_region                          = var.cloud_build_region
  cws_image_build_runner_role_create          = var.cws_image_build_runner_role_create
  cws_image_build_runner_role_id              = var.cws_image_build_runner_role_id
  cws_image_build_runner_role_title           = var.cws_image_build_runner_role_title
  git_branch_trigger                          = var.git_branch_trigger
  git_branches_regexp_trigger                 = var.git_branches_regexp_trigger
  github_owner                                = var.github_owner
  github_repo                                 = var.github_repo
  secret_manager_region                       = var.secret_manager_region
  secure_source_manager_always_create         = var.secure_source_manager_always_create
  secure_source_manager_deletion_policy       = var.secure_source_manager_deletion_policy
  secure_source_manager_instance_id           = var.secure_source_manager_instance_id
  secure_source_manager_instance_name         = var.secure_source_manager_instance_name
  secure_source_manager_region                = var.secure_source_manager_region
  secure_source_manager_repo_git_url_to_clone = var.secure_source_manager_repo_git_url_to_clone
  secure_source_manager_repo_name             = var.secure_source_manager_repo_name
  # go/keep-sorted end
}
