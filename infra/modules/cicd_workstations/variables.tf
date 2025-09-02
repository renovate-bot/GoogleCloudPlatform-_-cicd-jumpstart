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

variable "project_id" {
  type        = string
  description = "Project-ID that references existing project for deploying Cloud Workstations."
}

variable "cws_service_account_name" {
  type        = string
  description = "Name of the Cloud Workstations Service Account"
  default     = "workstations"
}

variable "cws_scopes" {
  type        = list(string)
  description = "The scope of the Cloud Workstations Service Account"
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "cws_clusters" {
  type = map(object({
    network    = string
    region     = string
    subnetwork = string
  }))
  description = "A map of Cloud Workstation clusters to create. The key of the map is used as the unique ID for the cluster."
  default     = {}
}

variable "cws_configs" {
  type = map(object({
    cws_cluster                    = string
    idle_timeout                   = number
    machine_type                   = string
    boot_disk_size_gb              = number
    disable_public_ip_addresses    = bool
    pool_size                      = number
    enable_nested_virtualization   = bool
    persistent_disk_size_gb        = number
    persistent_disk_fs_type        = string
    persistent_disk_type           = string
    persistent_disk_reclaim_policy = string
    image                          = optional(string)
    creators                       = optional(list(string))
    instances = optional(list(object({
      name  = string
      users = list(string)
    })))
  }))
  description = "A map of Cloud Workstation configurations."
  default     = {}
}
