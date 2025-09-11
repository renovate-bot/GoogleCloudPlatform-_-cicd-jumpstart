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
  has_kritis_signer = var.kritis_signer_image != null && var.kritis_signer_image != ""
  policy_content    = var.kritis_policy_file == null ? var.kritis_policy_default : file(var.kritis_policy_file)
  source_uri        = local.github_source ? "https://github.com/${var.github_owner}/${var.github_repo}.git" : google_secure_source_manager_repository.cicd_foundation.uris[0].git_https
}

# cf. https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts
module "service_account_cloud_build" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v36.0.1"

  project_id   = local.build_project_id
  name         = "${local.prefix}${var.cloud_build_service_account_name}"
  display_name = "Cloud Build Service Account"
  description  = "Terraform-managed."
  iam_project_roles = {
    (local.build_project_id) : [
      # go/keep-sorted start
      "roles/cloudbuild.builds.builder",
      "roles/clouddeploy.releaser",
      "roles/containeranalysis.notes.attacher",
      "roles/containeranalysis.notes.occurrences.viewer",
      "roles/containeranalysis.occurrences.editor",
      # go/keep-sorted end
    ],
  }
}

resource "google_cloudbuild_worker_pool" "pool" {
  for_each = { for k, v in var.stages : k => v if v.peered_network != null }

  name     = "${local.prefix}${var.cloud_build_pool_name}-${each.key}"
  project  = var.stages[each.key].project_id
  location = var.cloud_build_region
  worker_config {
    disk_size_gb   = var.cloud_build_pool_disk_size_gb
    machine_type   = var.cloud_build_pool_machine_type
    no_external_ip = true
  }
  network_config {
    peered_network = var.stages[each.key].peered_network
  }
}

resource "google_cloudbuild_trigger" "continuous_integration" {
  for_each = var.apps

  name            = "${local.prefix}${each.key}"
  project         = local.build_project_id
  location        = var.cloud_build_region
  service_account = module.service_account_cloud_build.id
  description     = "Terraform-managed."
  dynamic "github" {
    for_each = local.github_source ? [1] : []

    content {
      owner = var.github_owner
      name  = var.github_repo
      push {
        branch = var.git_branches_regexp_trigger
      }
    }
  }
  dynamic "webhook_config" {
    for_each = local.github_source ? [] : [1]

    content {
      secret = google_secret_manager_secret_version.webhook_trigger.id
    }
  }
  source_to_build {
    uri       = local.source_uri
    ref       = "refs/heads/${var.git_branch_trigger}"
    repo_type = local.github_source ? "GITHUB" : "UNKNOWN"
  }
  build {
    dynamic "step" {
      for_each = local.github_source ? [] : [1]

      content {
        id         = "clone"
        name       = "gcr.io/cloud-builders/git"
        entrypoint = "/bin/sh"
        args = [
          "-c",
          <<-EOT
            git clone "$${_GIT_CLONE_URL}" /workspace
            if [ -n "$${COMMIT_SHA}" ]; then
              cd /workspace
              git reset --hard "$${COMMIT_SHA}"
            fi
          EOT
        ]
      }
    }
    step {
      id         = "build"
      dir        = try(each.value.build.dockerfile_path, "apps/${each.key}")
      name       = "gcr.io/k8s-skaffold/skaffold:$${_SKAFFOLD_IMAGE_TAG}"
      entrypoint = "/bin/sh"
      args = [
        "-c",
        <<-EOT
          skaffold build \
            --default-repo=$${_SKAFFOLD_DEFAULT_REPO} \
            --interactive=false \
            --file-output=$${_SKAFFOLD_OUTPUT} \
            --quiet=$${_SKAFFOLD_QUIET}
        EOT
      ]
    }
    step {
      id         = "fetchImageDigest"
      wait_for   = ["build"]
      dir        = try(each.value.build.dockerfile_path, "apps/${each.key}")
      name       = "gcr.io/cloud-builders/docker:$${_DOCKER_IMAGE_TAG}"
      entrypoint = "/bin/sh"
      args = [
        "-c",
        <<-EOT
          /bin/grep -Po '"tag":"\K[^"]*"' "$${_SKAFFOLD_OUTPUT}" > images.txt
          IMAGES=$$(/bin/cat images.txt)
          for IMAGE in $$IMAGES; do
            IMAGE_NAME=$$(/bin/echo "$$IMAGE" | /bin/sed 's/\([^:]*\).*/\1/')
            DIGEST_FILENAME=$$(/bin/echo "$$IMAGE" | /bin/sed 's/.*@sha256://').digest
            docker pull "$$IMAGE" && \
            docker tag "$$IMAGE" "$$IMAGE_NAME:latest" && \
            docker push "$$IMAGE_NAME:latest" && \
            docker image inspect "$$IMAGE" --format='{{index .RepoDigests 0}}' > "$$DIGEST_FILENAME"
          done
        EOT
      ]
    }
    dynamic "step" {
      for_each = local.has_kritis_signer ? [1] : []

      content {
        id         = "vulnsign"
        wait_for   = ["fetchImageDigest"]
        name       = "$_KRITIS_SIGNER_IMAGE"
        entrypoint = "/bin/sh"
        args = [
          "-c",
          <<-EOT
          POLICY_FILE=$(mktemp)
          echo "$${_KRITIS_POLICY_BASE64}" | base64 -d > "$$POLICY_FILE"
          IMAGES=$$(/bin/cat ./$${_DOCKERFILE_PATH}/images.txt)
          for IMAGE in $$IMAGES; do
            DIGEST_FILENAME=$$(/bin/echo "$$IMAGE" | /bin/sed 's/.*@sha256://').digest
            IMAGE_DIGEST=$$(/bin/cat "./$${_DOCKERFILE_PATH}/$$DIGEST_FILENAME")
            /kritis/signer \
              -v=10 \
              -alsologtostderr \
              -image="$$IMAGE_DIGEST" \
              -policy="$$POLICY_FILE" \
              -kms_key_name="$${_KMS_KEY_NAME}" \
              -kms_digest_alg="$${_KMS_DIGEST_ALG}" \
              -note_name="$${_NOTE_NAME}"
          done
          rm -f "$$POLICY_FILE"
          EOT
        ]
        allow_failure = true
      }
    }
    dynamic "step" {
      for_each = try(google_clouddeploy_delivery_pipeline.continuous_delivery[each.key].name, "") == "" ? [] : [1]

      content {
        id         = "createRelease"
        wait_for   = [local.has_kritis_signer ? "vulnsign" : "fetchImageDigest"]
        dir        = try(each.value.build.dockerfile_path, "apps/${each.key}")
        name       = "gcr.io/google.com/cloudsdktool/cloud-sdk:$${_GCLOUD_IMAGE_TAG}"
        entrypoint = "/bin/sh"
        args = [
          "-c",
          <<-EOT
            gcloud deploy releases create "rel-$${SHORT_SHA}" \
              --delivery-pipeline="$${_PIPELINE_NAME}" \
              --build-artifacts="$${_SKAFFOLD_OUTPUT}" \
              --labels="commit-sha=$COMMIT_SHA,commit-short-sha=$SHORT_SHA,commitId=$REVISION_ID,gcb-build-id=$BUILD_ID" \
              --annotations="commit-sha=$COMMIT_SHA,commit-short-sha=$SHORT_SHA,commitId=$REVISION_ID,gcb-build-id=$BUILD_ID" \
              --region="$${_REGION}" \
              --deploy-parameters="commit-sha=$COMMIT_SHA,commit-short-sha=$SHORT_SHA,commitId=$REVISION_ID,gcb-build-id=$BUILD_ID,namespace=$${_NAMESPACE}"
          EOT
        ]
      }
    }
    timeout = try("${each.value.build.timeout}s", "${var.build_timeout_default_seconds}s")
    options {
      requested_verify_option = "VERIFIED"
      logging                 = "CLOUD_LOGGING_ONLY"
      machine_type            = each.value.build == null ? var.build_machine_type_default : each.value.build.machine_type
    }
  }
  included_files = [
    "${try(each.value.build.dockerfile_path, "apps/${each.key}")}/**"
  ]
  substitutions = {
    # go/keep-sorted start
    _APP_NAME              = each.key
    _DOCKERFILE_PATH       = try(each.value.build.dockerfile_path, "apps/${each.key}")
    _DOCKER_IMAGE_TAG      = var.docker_image_tag
    _GCLOUD_IMAGE_TAG      = var.gcloud_image_tag
    _GIT_CLONE_URL         = local.github_source ? "" : local.source_uri
    _KMS_DIGEST_ALG        = var.kms_digest_alg
    _KMS_KEY_NAME          = var.kms_key_name
    _KRITIS_POLICY_BASE64  = base64encode(local.policy_content)
    _KRITIS_SIGNER_IMAGE   = var.kritis_signer_image
    _NAMESPACE             = var.namespace
    _NOTE_NAME             = google_container_analysis_note.vulnz_attestor.id
    _PIPELINE_NAME         = try(google_clouddeploy_delivery_pipeline.continuous_delivery[each.key].name, "")
    _REGION                = var.cloud_build_region
    _SKAFFOLD_DEFAULT_REPO = local.artifact_registry_repository_uri
    _SKAFFOLD_IMAGE_TAG    = var.skaffold_image_tag
    _SKAFFOLD_OUTPUT       = var.skaffold_output
    _SKAFFOLD_QUIET        = var.skaffold_quiet
    # go/keep-sorted end
  }
}
