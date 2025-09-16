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

variable "enable_apis" {
  type        = bool
  description = "Whether to enable the required APIs for the module."
  default     = true
}

variable "project_id" {
  type        = string
  description = "Project-ID that references existing project."
}

# Location/Region Variables

variable "region" {
  type        = string
  description = "Compute region used."
  default     = "us-central1"
}

variable "secure_source_manager_region" {
  type        = string
  description = "The region for the Secure Source Manager instance, cf. https://cloud.google.com/secure-source-manager/docs/locations."
  default     = "us-central1"
}

# Networking

# go/keep-sorted start block=yes newline_separated=yes
variable "create_vpc" {
  type        = bool
  description = "Flag indicating whether the VPC should be created or not."
  default     = true
}

variable "psa_cidr" {
  type        = string
  description = "PSA CIDR range"
  default     = "10.60.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "CIDR for the primary subnet in the VPC"
  default     = "10.8.0.0/16"
}

variable "subnet_name" {
  type        = string
  description = "Name of the Virtual Private Cloud (VPC) network for the workstation in a region."
  default     = "primary"
}

variable "vpc_name" {
  type        = string
  description = "Name of the Virtual Private Cloud (VPC) network for the workstation."
  default     = "workstations"
}
# go/keep-sorted end

# Artifact Registry
variable "artifact_registry_repository_id" {
  type        = string
  description = "The ID of the Artifact Registry repository for container images."
  default     = "cloud-workstations-images"
}

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
  type        = string
  description = "The name of the Secure Source Manager instance."
  default     = "workstation-images"
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
    creators                        = optional(list(string))
    instances = optional(list(object({
      name  = string
      users = list(string)
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
  default = {
    // go/keep-sorted start block=yes
    "android-studio" : {
      build = {
        dockerfile_path = "examples/images/android/android-studio"
        timeout_seconds = 7200
        machine_type    = "E2_HIGHCPU_32"
      }
    },
    "android-studio-for-platform" : {
      build = {
        dockerfile_path = "examples/images/android-open-source-project/android-studio-for-platform"
        timeout_seconds = 7200
        machine_type    = "E2_HIGHCPU_32"
      }
    },
    "code-oss" : {
      build = {
        dockerfile_path = "examples/images/android-open-source-project/code-oss"
        timeout_seconds = 7200
        machine_type    = "E2_HIGHCPU_32"
      }
    },
    "repo-builder" : {
      build = {
        dockerfile_path = "examples/images/android-open-source-project/repo-builder"
        timeout_seconds = 7200
        machine_type    = "E2_HIGHCPU_32"
      }
    },
    // go/keep-sorted end
  }
}

## Android Platform Development

variable "android_branches" {
  type        = list(string)
  description = "Android branches to build"
  default     = []
}

variable "android_targets" {
  type        = map(string)
  description = <<-EOT
    Android `lunch` targets to build.
    The keys of this maps are used for the names of the Workstation Configs.
    The values are the actual lunch targets.
  EOT
  default     = {}
}
