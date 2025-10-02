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
  # go/keep-sorted start block=yes newline_separated=yes
  # A filtered product of applications and trigger types.
  # Each entry contains the name (from var.apps), the corresponding config (from var.apps), and the trigger type (from local.trigger_sources).
  # Webhook triggers are only created if using SSM.
  # Manual and GitHub triggers are only created if using GitHub.
  ci_apps = {
    for app_source in setproduct(keys(var.apps), ["github", "manual", "webhook"]) : contains(["github"], app_source[1]) ? "${app_source[0]}-${app_source[1]}" : "${app_source[0]}" => {
      name         = app_source[0]
      config       = var.apps[app_source[0]]
      trigger_type = app_source[1]
    }
    if(app_source[1] == "webhook" && local.source.ssm) || (app_source[1] == "github" && local.source.github) || (app_source[1] == "manual" && local.source.github)
  }

  # Boolean flags for each application source combination.
  # This helps in conditionally configuring build steps and trigger settings.
  ci_apps_flags = {
    for k, v in local.ci_apps : k => {
      is_github_trigger     = v.trigger_type == "github",
      is_webhook_trigger    = v.trigger_type == "webhook",
      needs_source_to_build = v.trigger_type == "manual" && local.source.github,
      needs_clone_step      = local.source.ssm
    }
  }

  # Build specifications for each combination in ci_apps.
  # Defines the build steps, timeout, and options based on the application and source type.
  ci_build_specs = {
    for app_source_key, app_source_config in local.ci_apps : app_source_key => {
      name         = app_source_config.name
      config       = app_source_config.config
      trigger_type = app_source_config.trigger_type
      postfix      = app_source_config.trigger_type == "github" ? "-github" : ""
      steps = concat(
        (local.ci_apps_flags[app_source_key].needs_clone_step) ? [
          # Clones the source repository into the workspace.
          {
            # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
            id            = "clone"
            name          = "gcr.io/cloud-builders/git"
            wait_for      = []
            allow_failure = false
            dir           = null
            entrypoint    = "/bin/sh"
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
            # go/keep-sorted end
          }
        ] : [],
        [
          # Builds the application images using Skaffold.
          {
            # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
            id            = "build"
            name          = "gcr.io/k8s-skaffold/skaffold:$${_SKAFFOLD_IMAGE_TAG}"
            wait_for      = (local.ci_apps_flags[app_source_key].needs_clone_step) ? ["clone"] : []
            allow_failure = false
            dir           = try(app_source_config.config.build.dockerfile_path, "apps/${app_source_config.name}")
            entrypoint    = "/bin/sh"
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
            # go/keep-sorted end
          },
          # Fetches the image digests and pushes a 'latest' tag for each built image.
          {
            # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
            id            = "fetchImageDigest"
            name          = "gcr.io/cloud-builders/docker:$${_DOCKER_IMAGE_TAG}"
            wait_for      = ["build"]
            allow_failure = false
            dir           = try(app_source_config.config.build.dockerfile_path, "apps/${app_source_config.name}")
            entrypoint    = "/bin/sh"
            args = [
              "-c",
              <<-EOT
                /bin/grep -Po '"tag":"\K[^"]*' "$${_SKAFFOLD_OUTPUT}" > images.txt
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
            # go/keep-sorted end
          }
        ],
        local.has_kritis_signer ? [
          # Signs the built images using the Kritis signer.
          {
            # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
            id            = "vulnsign"
            name          = "$_KRITIS_SIGNER_IMAGE"
            wait_for      = ["fetchImageDigest"]
            allow_failure = true
            dir           = null
            entrypoint    = "/bin/sh"
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
            # go/keep-sorted end
          }
        ] : [],
        try(google_clouddeploy_delivery_pipeline.continuous_delivery[app_source_config.name].name, "") == "" ? [] : [
          # Creates a Cloud Deploy release from the built artifacts.
          {
            # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
            id            = "createRelease"
            name          = "gcr.io/google.com/cloudsdktool/cloud-sdk:$${_GCLOUD_IMAGE_TAG}"
            wait_for      = [local.has_kritis_signer ? "vulnsign" : "fetchImageDigest"]
            allow_failure = false
            dir           = try(app_source_config.config.build.dockerfile_path, "apps/${app_source_config.name}")
            entrypoint    = "/bin/sh"
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
            # go/keep-sorted end
          }
        ]
      )
      timeout = try("${app_source_config.config.build.timeout_seconds}s", "${var.build_timeout_default_seconds}s")
      options = {
        requested_verify_option = "VERIFIED"
        logging                 = "CLOUD_LOGGING_ONLY"
        machine_type            = app_source_config.config.build == null ? var.build_machine_type_default : app_source_config.config.build.machine_type
      }
    }
  }

  # Files to include in the Cloud Build context for each application,
  # typically based on the dockerfile_path.
  ci_included_files = {
    for app_name, app_config in var.apps : app_name => [
      "${try(app_config.build.dockerfile_path, "apps/${app_name}")}/**",
    ]
  }

  # Cloud Build substitutions for each app/source combination.
  # Includes details like Dockerfile path, image tags, KMS keys, and pipeline names.
  ci_substitutions = {
    for app_source_key, app_source_config in local.ci_apps : app_source_key => {
      # go/keep-sorted start
      _APP_NAME              = app_source_config.name
      _DOCKERFILE_PATH       = try(app_source_config.config.build.dockerfile_path, "apps/${app_source_config.name}")
      _DOCKER_IMAGE_TAG      = var.docker_image_tag
      _GCLOUD_IMAGE_TAG      = var.gcloud_image_tag
      _GIT_CLONE_URL         = (local.ci_apps_flags[app_source_key].needs_clone_step) ? local.source_uri : ""
      _KMS_DIGEST_ALG        = var.kms_digest_alg
      _KMS_KEY_NAME          = var.kms_key_name
      _KRITIS_POLICY_BASE64  = base64encode(local.policy_content)
      _KRITIS_SIGNER_IMAGE   = var.kritis_signer_image
      _NAMESPACE             = var.namespace
      _NOTE_NAME             = google_container_analysis_note.vulnz_attestor.id
      _PIPELINE_NAME         = try(google_clouddeploy_delivery_pipeline.continuous_delivery[app_source_config.name].name, "")
      _REGION                = var.cloud_build_region
      _SKAFFOLD_DEFAULT_REPO = local.artifact_registry_repository_uri
      _SKAFFOLD_IMAGE_TAG    = var.skaffold_image_tag
      _SKAFFOLD_OUTPUT       = var.skaffold_output
      _SKAFFOLD_QUIET        = var.skaffold_quiet
      # go/keep-sorted end
    }
  }

  # Boolean indicating whether a Kritis signer image is provided.
  has_kritis_signer = var.kritis_signer_image != null && var.kritis_signer_image != ""

  # The content of the Kritis policy file, or the default policy if not specified.
  policy_content = var.kritis_policy_file == null ? var.kritis_policy_default : file(var.kritis_policy_file)

  # The source repository solution: GitHub or Secure Source Manager.
  source_solution = local.source.github ? "github" : (local.source.ssm ? "ssm" : null)

  # The URI for the source repository, either from GitHub or Secure Source Manager.
  source_uri = lookup(local.source_uris, local.source_solution, "")

  # Map of source types to their URIs.
  source_uris = merge(
    local.source.github ? {
      "github" : "https://github.com/${var.github_owner}/${var.github_repo}.git"
    } : {},
    local.source.ssm ? {
      "ssm" : google_secure_source_manager_repository.cicd_foundation[0].uris[0].git_https
    } : {}
  )
  # go/keep-sorted end
}

# cf. https://cloud.google.com/build/docs/securing-builds/configure-user-specified-service-accounts
module "service_account_cloud_build" {
  source = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=v45.0.0"

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

  project  = var.stages[each.key].project_id
  name     = "${local.prefix}${var.cloud_build_pool_name}-${each.key}"
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

resource "google_cloudbuild_trigger" "ci_pipeline" {
  for_each = local.ci_build_specs

  project         = local.build_project_id
  name            = "${local.prefix}${each.value.name}${each.value.postfix}"
  location        = var.cloud_build_region
  service_account = module.service_account_cloud_build.id
  description     = "Terraform-managed."

  # go/keep-sorted start block=yes newline_separated=yes
  dynamic "github" {
    for_each = local.ci_apps_flags[each.key].is_github_trigger ? [1] : []

    content {
      owner = var.github_owner
      name  = var.github_repo
      push {
        branch = var.git_branches_regexp_trigger
      }
    }
  }

  dynamic "source_to_build" {
    for_each = local.ci_apps_flags[each.key].needs_source_to_build ? [1] : []

    content {
      uri       = local.source_uri
      ref       = "refs/heads/${var.git_branch_trigger}"
      repo_type = local.source.github ? "GITHUB" : "UNKNOWN"
    }
  }

  dynamic "webhook_config" {
    for_each = local.ci_apps_flags[each.key].is_webhook_trigger ? [1] : []

    content {
      secret = google_secret_manager_secret_version.webhook_trigger[0].id
    }
  }
  # go/keep-sorted end

  build {
    dynamic "step" {
      for_each = each.value.steps

      content {
        # go/keep-sorted start prefix_order=id,name,wait_for,allow_failure,dir,entrypoint,args
        id            = step.value.id
        name          = step.value.name
        wait_for      = step.value.wait_for
        allow_failure = step.value.allow_failure
        dir           = step.value.dir
        entrypoint    = step.value.entrypoint
        args          = step.value.args
        # go/keep-sorted end
      }
    }
    timeout = each.value.timeout
    options {
      requested_verify_option = each.value.options.requested_verify_option
      logging                 = each.value.options.logging
      machine_type            = each.value.options.machine_type
    }
  }
  included_files = local.ci_included_files[each.value.name]
  substitutions  = local.ci_substitutions[each.key]

  lifecycle {
    ignore_changes = [
      included_files,
      source_to_build,
    ]
  }
}
