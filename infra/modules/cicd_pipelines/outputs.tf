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

# Source Control (Secure Source Manager)

# go/keep-sorted start block=yes newline_separated=yes
output "secure_source_manager_instance_git_http" {
  description = "The Git HTTP URI of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].git_http
}

output "secure_source_manager_instance_git_ssh" {
  description = "The Git SSH URI of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].git_ssh
}

output "secure_source_manager_instance_html" {
  description = "The HTML hostname of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.host_config[0].html
}

output "secure_source_manager_instance_id" {
  description = "The ID of the created Secure Source Manager instance."
  value       = google_secure_source_manager_instance.source.id
}
# go/keep-sorted end

# Artifact Registry

# go/keep-sorted start block=yes newline_separated=yes
output "artifact_registry_repository" {
  description = "The Artifact Registry repository object."
  value       = data.google_artifact_registry_repository.container_repository
}
# go/keep-sorted end
