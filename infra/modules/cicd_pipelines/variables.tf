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

# General Project & Naming

# go/keep-sorted start block=yes newline_separated=yes
variable "enable_apis" {
  type        = bool
  description = "Whether to enable the required APIs for the module."
  default     = true
}

variable "namespace" {
  type        = string
  description = "A prefix to be added to resource names to ensure uniqueness."
  default     = ""
}

variable "project_id" {
  type        = string
  description = "The ID of the Google Cloud project where resources will be deployed."
}
# go/keep-sorted end

# Location/Region Variables

# go/keep-sorted start block=yes newline_separated=yes
variable "artifact_registry_region" {
  type        = string
  description = "The region to use for Artifact Registry resources."
  default     = "us-central1"
}

variable "cloud_build_region" {
  type        = string
  description = "The region to use for Cloud Build resources."
  default     = "us-central1"
}

variable "deploy_region" {
  type        = string
  description = "The region to use for Cloud Deploy resources."
  default     = "us-central1"
}

variable "kms_keyring_location" {
  type        = string
  description = "The location for the KMS keyring."
  default     = "us-central1"
}

variable "scheduler_default_region" {
  type        = string
  description = "The default region for the Cloud Scheduler if not specified in the application config."
  default     = "us-central1"
}

variable "secret_manager_region" {
  type        = string
  description = "The region for the Secret Manager, cf. https://cloud.google.com/secret-manager/docs/locations."
  default     = "us-central1"
}

variable "secure_source_manager_region" {
  type        = string
  description = "The region for the Secure Source Manager instance, cf. https://cloud.google.com/secure-source-manager/docs/locations."
  default     = "us-central1"
}
# go/keep-sorted end

# Applications & Stages

# go/keep-sorted start block=yes newline_separated=yes
variable "apps" {
  type = map(object({
    build = optional(object({
      # The relative path to the Dockerfile within the repository.
      dockerfile_path = optional(string)
      # The timeout for the build in seconds.
      timeout = number
      # The machine type to use for the build.
      machine_type = string
      })
    )
    runtime = optional(string, "cloudrun"),
    stages  = optional(map(map(string)))
    workstation_config = optional(object({
      # The region to use for the Cloud Scheduler job.
      scheduler_region = string
      # The schedule for the Cloud Scheduler job in cron format (e.g., "0 1 * * *")
      ci_schedule = string
    }))
  }))
  description = <<EOF
  Map of applications to be deployed. Keys are application names, values configure
  build, runtime, and stage-specific parameters. The `stages` attribute is a map
  where keys are stage names (e.g., 'dev', 'prod'). The value for each stage is
  another map, where keys are used Cloud Deploy tags in the respective pipelines.
  EOF
  default     = {}
  validation {
    condition = alltrue([
      for app_key, app_value in var.apps :
      contains(var.runtimes, app_value.runtime)
    ])
    error_message = "Runtime must be one of the allowed runtimes: ${join(", ", var.runtimes)}."
  }
  validation {
    condition = alltrue([
      for app_key, app_value in var.apps :
      # Check that if 'stages' is provided, all keys are valid.
      (lookup(app_value, "stages", {}) == null ? true : alltrue([
        for stage_key, stage_value in lookup(app_value, "stages", {}) :
        alltrue([
          for k in keys(stage_value) :
          contains(keys(var.stages), k)
        ])
      ]))
    ])
    error_message = "Stages must be a subset of the allowed stages: ${join(", ", keys(var.stages))}."
  }
}

variable "runtimes" {
  type        = list(string)
  description = "List of supported runtime solutions for applications."
  default     = ["cloudrun", "gke", "workstations"]
}

variable "stages" {
  type = map(object({
    cloud_run_region                      = optional(string)
    gke_cluster                           = optional(string)
    project_id                            = optional(string)
    peered_network                        = optional(string)
    require_approval                      = optional(bool, false)
    canary_percentages                    = optional(list(number))
    canary_verify                         = optional(bool, false)
    binary_authorization_evaluation_mode  = optional(string, "ALWAYS_ALLOW")
    binary_authorization_enforcement_mode = optional(string, "DRYRUN_AUDIT_LOG_ONLY")
  }))
  description = "Map of deployment stages (e.g., dev, test, prod). Keys are stage names, values configure stage-specific settings like cluster, network, and Binary Authorization."
  default = {
    "dev" : {},
    "test" : {},
    "prod" : {},
  }
  validation {
    condition = alltrue([
      for stage_key, stage_value in var.stages :
      ! contains(keys(stage_value), "canary_percentages") || contains(keys(stage_value), "gke_cluster")
    ])
    error_message = "The 'canary_percentages' can only be set when 'gke_cluster' is also provided for the stage."
  }
  validation {
    condition = alltrue([
      for stage_key, stage_value in var.stages :
      contains(keys(stage_value), "canary_percentages") == contains(keys(stage_value), "canary_verify")
    ])
    error_message = "If either 'canary_percentages' or 'canary_verify' is set, both must be provided."
  }
}
# go/keep-sorted end

# Source Control (GitHub & Secure Source Manager)

# go/keep-sorted start block=yes newline_separated=yes
variable "git_branch_trigger" {
  type        = string
  description = "The Secure Source Manager (SSM) branch that triggers Cloud Build on push."
  default     = "main"
}

variable "git_branches_regexp_trigger" {
  type        = string
  description = "A regular expression to match GitHub branches that trigger Cloud Build on push."
  default     = "^main$"
}

variable "github_owner" {
  type        = string
  description = "The owner of the GitHub repository (user or organization)."
  default     = null
}

variable "github_repo" {
  type        = string
  description = "The name of the GitHub repository."
  default     = null
}

variable "secure_source_manager_instance_name" {
  description = "The name of the Secure Source Manager instance."
  type        = string
  default     = "cicd-foundation"
}
# go/keep-sorted end

# Cloud Scheduler

variable "default_ci_schedule" {
  type        = string
  description = "The default cron schedule for continuous integration triggers in Cloud Scheduler if not specified in the application config."
  default     = "0 0 * * *"
}

# Cloud Build

# go/keep-sorted start block=yes newline_separated=yes
variable "build_machine_type_default" {
  type        = string
  description = "The default machine type to use for Cloud Build jobs."
  default     = "UNSPECIFIED"
}

variable "build_timeout_default_seconds" {
  type        = number
  description = "The default timeout in seconds for Cloud Build jobs."
  default     = 7200
}

variable "cloud_build_pool_disk_size_gb" {
  type        = number
  description = "The disk size in GB for Cloud Build worker pool workers."
  default     = 100
}

variable "cloud_build_pool_machine_type" {
  type        = string
  description = "The machine type for Cloud Build worker pool workers."
  default     = "e2-standard-2"
}

variable "cloud_build_pool_name" {
  type        = string
  description = "The base name for the Cloud Build worker pools. Stage name will be appended."
  default     = "worker-pool"
}

variable "cloud_build_service_account_name" {
  type        = string
  description = "The name of the Cloud Build service account to create."
  default     = "cloudbuild"
}

variable "docker_image_tag" {
  type        = string
  description = "The tag of the Docker container image to use in build steps."
  default     = "20.10.24"
}

variable "gcloud_image_tag" {
  type        = string
  description = "The tag of the gcr.io/google.com/cloudsdktool/cloud-sdk image to use."
  default     = "490.0.0"
}

variable "skaffold_image_tag" {
  type        = string
  description = "The tag of the gcr.io/k8s-skaffold/skaffold image to use."
  default     = "v2.13.2-lts"
}

variable "skaffold_output" {
  type        = string
  description = "The filename for the Skaffold artifacts JSON output."
  default     = "artifacts.json"
}

variable "skaffold_quiet" {
  type        = bool
  description = "Suppress Skaffold console output during builds."
  default     = false
}
# go/keep-sorted end

# Binary Authorization

# go/keep-sorted start block=yes newline_separated=yes
variable "kms_digest_alg" {
  type        = string
  description = "The digest algorithm to use for KMS signing."
  default     = "SHA512"
}

variable "kms_key_name" {
  type        = string
  description = "The name of the KMS key used for signing attestations."
  default     = "vulnz-attestor-key"
}

variable "kms_keyring_name" {
  type        = string
  description = "The name of the KMS key ring."
  default     = "vulnz-attestor-keyring"
}

variable "kms_signing_alg" {
  type        = string
  description = "The KMS signing algorithm to use for the vulnerability attestor key."
  default     = "RSA_SIGN_PKCS1_4096_SHA512"
}

variable "kritis_policy_default" {
  type        = string
  description = "The default YAML content of the Kritis vulnerability signing policy."
  default     = <<-EOT
apiVersion: kritis.grafeas.io/v1beta1
kind: VulnzSigningPolicy
metadata:
  name: cicd-foundation
spec:
  imageVulnerabilityRequirements:
    maximumFixableSeverity: MEDIUM
    maximumUnfixableSeverity: LOW
    allowlistCVEs:
#    - projects/goog-vulnz/notes/CVE-2023-39321
EOT
}

variable "kritis_policy_file" {
  type        = string
  description = "Path to a Kritis vulnerability signing policy YAML file. If null, the content from kritis_policy_default is used."
  default     = null
}

variable "kritis_signer_image" {
  type        = string
  description = "The container image reference for the Kritis signer. If empty, signing is disabled."
  default     = ""
}

variable "vulnz_attestor_name" {
  type        = string
  description = "The name of the Binary Authorization Attestor and the Container Analysis note."
  default     = "vulnz-attestor"
}
# go/keep-sorted end

# Artifact Registry

# go/keep-sorted start block=yes newline_separated=yes
variable "artifact_registry_id" {
  type        = string
  description = "The ID of an existing Docker Artifact Registry to use. If null, a new one will be created."
  default     = null
}

variable "artifact_registry_name" {
  type        = string
  description = "The name of the Artifact Registry repository to create if artifact_registry_id is null."
  default     = "container-registry"
}

variable "artifact_registry_readers" {
  type        = list(string)
  description = "List of service account emails in IAM email format to grant Artifact Registry reader role."
  default     = []
}
# go/keep-sorted end

# Cloud Deploy

# go/keep-sorted start block=yes newline_separated=yes
variable "canary_route_update_wait_time" {
  type        = number
  description = "The time (in seconds) to wait for network route updates during GKE canary deployments."
  default     = 60
}

variable "canary_verify" {
  type        = bool
  description = "Whether to enable verification steps for canary deployments in Cloud Deploy."
  default     = true
}

variable "service_account_cloud_deploy_name" {
  type        = string
  description = "The base name for the Cloud Deploy service accounts. Stage name will be appended."
  default     = "cloud-deploy"
}
# go/keep-sorted end
