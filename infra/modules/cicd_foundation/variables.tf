# Copyright 2024-2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
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

variable "labels" {
  type        = map(string)
  description = "Common labels to be applied to resources."
  default     = {}
}

variable "project_id" {
  type        = string
  description = "Project-ID that references existing project."
}
# go/keep-sorted end

# Location/Region Variables

# go/keep-sorted start block=yes newline_separated=yes
variable "artifact_registry_region" {
  type        = string
  description = "The region for Artifact Registry."
  default     = "us-central1"
}

variable "cloud_build_region" {
  type        = string
  description = "The region for Cloud Build."
  default     = "us-central1"
}

variable "secret_manager_region" {
  type        = string
  description = "The region for Secret Manager."
  default     = "us-central1"
}

variable "secure_source_manager_region" {
  type        = string
  description = "The region for the Secure Source Manager instance, cf. https://cloud.google.com/secure-source-manager/docs/locations."
  default     = "us-central1"
}
# go/keep-sorted end

# Applications & Stages

variable "apps" {
  type = map(object({
    build = optional(object({
      # The relative path to the Dockerfile within the repository.
      dockerfile_path = optional(string)
      # The timeout for the build in seconds.
      timeout_seconds = number
      # The machine type to use for the build.
      machine_type = string
      })
    )
    runtime = optional(string, "cloudrun"),
    stages  = optional(map(map(string)))
  }))
  description = "Map of applications to be deployed."
  default     = {}
}

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
  default     = "cicd-foundation"
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

variable "secure_source_manager_always_create" {
  type        = bool
  description = "If true, create Secure Source Manager resources (instance, repository). These resources can be created even when a GitHub repository is also specified as the trigger source."
  default     = false
}

variable "secure_source_manager_deletion_policy" {
  type        = string
  description = "The deletion policy for the Secure Source Manager instance and repository. One of DELETE, PREVENT, or ABANDON."
  default     = "PREVENT"
}

variable "secure_source_manager_instance_id" {
  type        = string
  description = "The full ID of an existing Secure Source Manager instance. If null, a new one will be created."
  default     = null
}

variable "secure_source_manager_instance_name" {
  type        = string
  description = "The name of the Secure Source Manager instance to create, if secure_source_manager_instance_id is null."
  default     = "cicd-foundation"
}

variable "secure_source_manager_repo_git_url_to_clone" {
  type        = string
  description = "The URL of a Git repository to clone into the new Secure Source Manager repository. If null, cloning is skipped."
  default     = null
}

variable "secure_source_manager_repo_name" {
  type        = string
  description = "The name of the Secure Source Manager repository."
  default     = "cicd-foundation"
}
# go/keep-sorted end

# Cloud Build

# go/keep-sorted start block=yes newline_separated=yes
variable "cloud_build_api_key_display_name" {
  type        = string
  description = "The display name of the API key for Cloud Build."
  default     = "API key for Cloud Build"
}

variable "cloud_build_api_key_name" {
  type        = string
  description = <<-EOT
    The name of the API key for Cloud Build.
    You can import an existing API key by specifying its name here
    and running `terraform import`.
  EOT
  default     = "cloudbuild"
}
# go/keep-sorted end

# Cloud Workstations

# go/keep-sorted start block=yes newline_separated=yes
variable "cws_image_build_runner_role_create" {
  type        = bool
  description = "Whether to create the custom IAM role for the Cloud Workstation Image Build Runner. If false, the role is expected to exist."
  default     = true
}

variable "cws_image_build_runner_role_id" {
  type        = string
  description = "The role_id for the custom IAM role for the Cloud Workstation Image Build Runner."
  default     = "cwsBuildRunner"
}

variable "cws_image_build_runner_role_title" {
  type        = string
  description = "The title for the custom IAM role for the Cloud Workstation Image Build Runner."
  default     = "Cloud Workstation Image Build Runner"
}
# go/keep-sorted end

# Cloud Workstations Clusters

variable "cws_clusters" {
  type = map(object({
    network    = string
    region     = string
    subnetwork = string
  }))
  description = "A map of Cloud Workstation clusters to create. The key of the map is used as the unique ID for the cluster."
  default     = {}
}

# Cloud Workstations Configs and instances

variable "cws_configs" {
  type = map(object({
    cws_cluster                     = string
    idle_timeout_seconds            = optional(number, 7200)
    machine_type                    = optional(string, "n1-standard-96")
    boot_disk_size_gb               = optional(number, 2000)
    disable_public_ip_addresses     = optional(bool, false)
    pool_size                       = optional(number, 0)
    enable_nested_virtualization    = optional(bool, true)
    persistent_disk_size_gb         = optional(number)
    persistent_disk_fs_type         = optional(string)
    persistent_disk_type            = string
    persistent_disk_reclaim_policy  = string
    persistent_disk_source_snapshot = optional(string)
    image                           = optional(string)
    # In case custom images shall be used, the keys from the cws_custom_images map.
    custom_image_names = optional(list(string), [])
    creators           = optional(list(string))
    display_name       = optional(string)
    instances = optional(list(object({
      name         = string
      display_name = optional(string)
      users        = list(string)
    })))
  }))
  description = "A map of Cloud Workstation configurations."
  default     = {}
  validation {
    condition = alltrue([
      for k, v in var.cws_configs :
      v.persistent_disk_source_snapshot == null || (v.persistent_disk_size_gb == null && v.persistent_disk_fs_type == null)
    ])
    error_message = "If persistent_disk_source_snapshot is provided, persistent_disk_size_gb and persistent_disk_fs_type must not be set."
  }
  validation {
    condition = alltrue([
      for k, v in var.cws_configs :
      v.persistent_disk_source_snapshot != null || (v.persistent_disk_size_gb != null && v.persistent_disk_fs_type != null)
    ])
    error_message = "If persistent_disk_source_snapshot is not provided, persistent_disk_size_gb and persistent_disk_fs_type must both be set."
  }
  validation {
    condition = alltrue([
      for k, v in var.cws_configs : v.image == null || length(coalesce(v.custom_image_names, [])) == 0
    ])
    error_message = "image and custom_image_names are mutually exclusive and cannot be set at the same time."
  }
  validation {
    condition = alltrue([
      for k, v in var.cws_configs : alltrue([
        for name in coalesce(v.custom_image_names, []) : contains(keys(var.cws_custom_images), name)
      ])
    ])
    error_message = "If custom_image_names is provided, all names must be keys in the cws_custom_images map."
  }
}

# Custom images for Cloud Workstations

variable "cws_custom_images" {
  type = map(object({
    build = optional(object({
      dockerfile_path = optional(string)
      timeout_seconds = number
      machine_type    = string
      })
    )
    workstation_config = optional(object({
      scheduler_region = string
      ci_schedule      = string
    }))
  }))
  description = <<-EOT
    Map of applications as found within the apps/ folder of the repository,
    their build configuration, runtime, deployment stages and parameters.
  EOT
  default     = {}
}
