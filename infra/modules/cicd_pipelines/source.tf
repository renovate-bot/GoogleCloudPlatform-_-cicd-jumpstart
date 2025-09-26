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
  instance_accessor_members = toset(concat(
    [module.service_account_cloud_build.iam_email],
    length(google_service_account.git_clone_and_push) > 0 ? [google_service_account.git_clone_and_push[0].member] : [],
  ))
  cloud_build_service_agent = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  ssm_instance_is_provided = var.secure_source_manager_instance_id != null

  ssm_project       = local.ssm_instance_is_provided ? split("/", var.secure_source_manager_instance_id)[1] : data.google_project.project.project_id
  ssm_location      = local.ssm_instance_is_provided ? split("/", var.secure_source_manager_instance_id)[3] : var.secure_source_manager_region
  ssm_instance_name = local.ssm_instance_is_provided ? split("/", var.secure_source_manager_instance_id)[5] : var.secure_source_manager_instance_name
  ssm_instance_id = local.source.ssm ? (
    local.ssm_instance_is_provided ?
    var.secure_source_manager_instance_id :
    google_secure_source_manager_instance.cicd_foundation[0].id
  ) : null
}

# Secure Source Manager (SSM) Instance

resource "google_secure_source_manager_instance" "cicd_foundation" {
  count = local.source.ssm && ! local.ssm_instance_is_provided ? 1 : 0

  project         = data.google_project.project.project_id
  location        = var.secure_source_manager_region
  instance_id     = var.secure_source_manager_instance_name
  labels          = local.common_labels
  deletion_policy = var.secure_source_manager_deletion_policy

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

resource "google_secure_source_manager_instance_iam_member" "instance_accessor" {
  for_each = local.source.ssm ? local.instance_accessor_members : toset([])

  project     = local.ssm_project
  location    = local.ssm_location
  instance_id = local.ssm_instance_name
  role        = "roles/securesourcemanager.instanceAccessor"
  member      = each.value
}

# Secure Source Manager (SSM) Repository

resource "google_secure_source_manager_repository" "cicd_foundation" {
  count = local.source.ssm ? 1 : 0

  project         = local.ssm_project
  location        = local.ssm_location
  instance        = local.ssm_instance_id
  repository_id   = "${local.prefix}${var.secure_source_manager_repo_name}"
  deletion_policy = var.secure_source_manager_deletion_policy
}

resource "google_secure_source_manager_repository_iam_binding" "repo_reader" {
  count = local.source.ssm ? 1 : 0

  project       = google_secure_source_manager_repository.cicd_foundation[0].project
  location      = google_secure_source_manager_repository.cicd_foundation[0].location
  repository_id = google_secure_source_manager_repository.cicd_foundation[0].repository_id
  role          = "roles/securesourcemanager.repoReader"
  members       = [module.service_account_cloud_build.iam_email]
}

# Secure Source Manager (SSM) Webhook

resource "google_secret_manager_secret" "webhook_trigger" {
  count = local.source.ssm ? 1 : 0

  project   = data.google_project.project.project_id
  secret_id = "${local.prefix}webhook-trigger"
  replication {
    user_managed {
      replicas {
        location = var.secret_manager_region
      }
    }
  }
}

resource "random_id" "webhook_secret_key" {
  count = local.source.ssm ? 1 : 0

  byte_length = 64
}

resource "google_secret_manager_secret_version" "webhook_trigger" {
  count = local.source.ssm ? 1 : 0

  secret      = google_secret_manager_secret.webhook_trigger[0].id
  secret_data = random_id.webhook_secret_key[0].hex
}

data "google_iam_policy" "secret_accessor" {
  binding {
    role = "roles/secretmanager.secretAccessor"
    members = [
      "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com",
    ]
  }
}

resource "google_secret_manager_secret_iam_policy" "policy" {
  count = local.source.ssm ? 1 : 0

  project     = google_secret_manager_secret.webhook_trigger[0].project
  secret_id   = google_secret_manager_secret.webhook_trigger[0].secret_id
  policy_data = data.google_iam_policy.secret_accessor.policy_data
}

# Clone a Git repo and push to Secure Source Manager (SSM) Repository

resource "google_service_account" "git_clone_and_push" {
  count = local.source.ssm && var.secure_source_manager_repo_git_url_to_clone != null ? 1 : 0

  project      = data.google_project.project.project_id
  account_id   = "tf-${local.prefix}git-clone"
  display_name = "SA for git-clone-and-push trigger"
  description  = "Terraform-managed."
}

resource "google_project_iam_member" "git_clone_and_push_log_writer" {
  count = local.source.ssm && var.secure_source_manager_repo_git_url_to_clone != null ? 1 : 0

  project = data.google_project.project.project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.git_clone_and_push[0].member
}

resource "google_service_account_iam_member" "git_clone_and_push_cb_user" {
  count = local.source.ssm && var.secure_source_manager_repo_git_url_to_clone != null ? 1 : 0

  service_account_id = google_service_account.git_clone_and_push[0].name
  role               = "roles/iam.serviceAccountUser"
  member             = local.cloud_build_service_agent
}

resource "google_secure_source_manager_repository_iam_binding" "repo_writer_git_clone" {
  count = local.source.ssm && var.secure_source_manager_repo_git_url_to_clone != null ? 1 : 0

  project       = google_secure_source_manager_repository.cicd_foundation[0].project
  location      = google_secure_source_manager_repository.cicd_foundation[0].location
  repository_id = google_secure_source_manager_repository.cicd_foundation[0].repository_id
  role          = "roles/securesourcemanager.repoWriter"
  members       = [google_service_account.git_clone_and_push[0].member]
}

resource "google_cloudbuild_trigger" "git_clone_and_push" {
  count = local.source.ssm && var.secure_source_manager_repo_git_url_to_clone != null ? 1 : 0

  project         = data.google_project.project.project_id
  name            = "tf-git-clone-and-push"
  location        = var.cloud_build_region
  service_account = google_service_account.git_clone_and_push[0].id
  description     = "Terraform managed."
  webhook_config {
    secret = google_secret_manager_secret_version.webhook_trigger[0].id
  }
  build {
    step {
      name       = "gcr.io/cloud-builders/git"
      id         = "git-clone-and-push"
      entrypoint = "sh"
      args = [
        "-c",
        <<EOT
          git config --global user.name "$${_USER_NAME}" && \
          git config --global user.email "$${_USER_EMAIL}" && \
          git config --global credential.'https://*.*.sourcemanager.dev'.helper gcloud.sh && \
          git clone $${_SOURCE_REPO_URL} . && \
          git remote add private $${_TARGET_REPO_URL} && \
          git push private $${_BRANCH_NAME}
        EOT
      ]
    }
    substitutions = {
      _BRANCH_NAME     = var.git_branch_trigger
      _SOURCE_REPO_URL = var.secure_source_manager_repo_git_url_to_clone
      _TARGET_REPO_URL = google_secure_source_manager_repository.cicd_foundation[0].uris[0].git_https
      _USER_EMAIL      = google_service_account.git_clone_and_push[0].email
      _USER_NAME       = "github.com/${local.default_labels["tf_module_github_org"]}/${local.default_labels["tf_module_github_repo"]}"
    }
    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }
}

resource "null_resource" "run_git_clone_and_push" {
  count = length(google_cloudbuild_trigger.git_clone_and_push) > 0 ? 1 : 0

  triggers = {
    ssm_repository_id = google_secure_source_manager_repository.cicd_foundation[0].id
  }

  provisioner "local-exec" {
    command = <<EOT
      gcloud builds triggers run \
        ${google_cloudbuild_trigger.git_clone_and_push[0].name} \
        --region=${var.cloud_build_region} \
        --project=${data.google_project.project.project_id}
    EOT
  }
  depends_on = [
    google_cloudbuild_trigger.git_clone_and_push,
    google_secure_source_manager_instance_iam_member.instance_accessor,
    google_secure_source_manager_repository_iam_binding.repo_writer_git_clone,
  ]
}
