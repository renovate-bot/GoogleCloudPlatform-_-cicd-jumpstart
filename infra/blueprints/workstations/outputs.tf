# Copyright 2024-2025 Google LLC
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

# go/keep-sorted start block=yes newline_separated=yes
output "secure_source_manager_repository_git_html" {
  description = "The Git HTML URI of the created Secure Source Manager repository."
  value       = length(var.cws_custom_images) > 0 ? module.cicd_foundation.secure_source_manager_repository_git_html : null
}

output "secure_source_manager_repository_git_https" {
  description = "The Git HTTP URI of the created Secure Source Manager repository."
  value       = length(var.cws_custom_images) > 0 ? module.cicd_foundation.secure_source_manager_repository_git_https : null
}

output "webhook_setup_instructions" {
  description = "Instructions to set up the webhook trigger."
  value       = length(var.cws_custom_images) > 0 ? module.cicd_foundation.webhook_setup_instructions : null
  sensitive   = true
}

output "webhook_setup_instructions_display" {
  description = "Instructions to set up the webhook trigger."
  value       = length(var.cws_custom_images) > 0 ? module.cicd_foundation.webhook_setup_instructions_display : null
}
# go/keep-sorted end
