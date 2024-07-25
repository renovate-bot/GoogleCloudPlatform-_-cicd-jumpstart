# Copyright 2023-2024 Google LLC
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

module "hub" {
  source = "./hub"

  project_id = var.project_id
  region     = var.region

  kritis_signer_image = var.kritis_signer_image

  developers = formatlist("user:%s", keys(var.developers))

  ws_pool_size = length(var.developers)

  cluster_name                = var.cluster_name
  cluster_min_version         = var.cluster_min_version
  cluster_release_channel     = var.cluster_release_channel
  cluster_deletion_protection = var.cluster_deletion_protection
}

module "team" {
  for_each = var.developers

  source = "./team"

  user_identity = each.key
  team          = join("", regexall("[a-zA-Z]", split("@", each.key)[0]))

  project_id = var.project_id
  region     = var.region

  ws_cluster_id = module.hub.ws_cluster_id
  ws_config_id  = module.hub.ws_config_id

  ssm_instance_name = module.hub.ssm_instance_name
  webhook_trigger_secret = module.hub.webhook_trigger_secret

  kritis_signer_image = var.kritis_signer_image
  kritis_note         = module.hub.kritis_note
  kms_key_name        = module.hub.kms_key_name

  sa-cb-id    = module.hub.cloud_build_sa_id
  sa-cb-email = module.hub.cloud_build_sa_email

  sa-cluster-prod-email = module.hub.sa-cluster-prod_email
  sa-cluster-test-email = module.hub.sa-cluster-test_email
  sa-cluster-dev-email  = module.hub.sa-cluster-dev_email

  apps = var.apps

  github_owner = each.value.github_user
  github_repo  = each.value.github_repo

  git_branch = var.git_branch

  skaffold_image_tag = var.skaffold_image_tag
  docker_image_tag   = var.docker_image_tag
  gcloud_image_tag   = var.gcloud_image_tag

  # for GKE
  cd_target_prod = module.hub.cd_target_cluster-prod
  cd_target_test = module.hub.cd_target_cluster-test
  cd_target_dev  = module.hub.cd_target_cluster-dev

  # for Cloud Run
  # cd_target_prod = module.hub.cd_target_run-prod
  # cd_target_test = module.hub.cd_target_run-test
  # cd_target_dev  = module.hub.cd_target_run-dev

  deploy_replicas = var.deploy_replicas
}
