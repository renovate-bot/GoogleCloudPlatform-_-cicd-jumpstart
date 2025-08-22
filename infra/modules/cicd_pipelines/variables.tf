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
  default     = "GoogleCloudPlaform"
}

variable "github_repo" {
  type        = string
  description = "The name of the GitHub repository."
  default     = "cicd-foundation"
}

variable "secure_source_manager_instance_name" {
  description = "The name of the Secure Source Manager instance."
  type        = string
  default     = "cicd-foundation"
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
# go/keep-sorted end
