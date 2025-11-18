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
  cluster_details = {
    for stage_key, stage_value in var.stages : stage_key => {
      full_name = stage_value.gke_cluster
      parsed    = regex("projects/(?:[^/]+)/locations/([^/]+)/clusters/([^/]+)", stage_value.gke_cluster)
    } if stage_value.gke_cluster != null
  }

  # Boolean indicating whether a Kritis signer image is provided.
  use_binary_authorization = var.kritis_signer_image != null && var.kritis_signer_image != ""

  # Boolean indicating whether to create binauth resources.
  create_binary_authorization_resources = local.use_binary_authorization || var.binary_authorization_always_create
}

resource "google_container_analysis_note" "vulnz_attestor" {
  count   = local.create_binary_authorization_resources ? 1 : 0

  project = data.google_project.project.project_id
  name    = "${local.prefix}${var.vulnz_attestor_name}"
  attestation_authority {
    hint {
      human_readable_name = "Vulnerability Attestor"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_container_analysis_note_iam_member" "vulnz_attestor_services" {
  count   = local.create_binary_authorization_resources ? 1 : 0

  project = google_container_analysis_note.vulnz_attestor[0].project
  note    = google_container_analysis_note.vulnz_attestor[0].name
  role    = "roles/containeranalysis.notes.occurrences.viewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_key_ring" "keyring" {
  count    = local.create_binary_authorization_resources ? 1 : 0

  project  = local.kms_project_id
  name     = "${local.prefix}${var.kms_keyring_name}"
  location = var.kms_keyring_location

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key" "vulnz_attestor_key" {
  count    = local.create_binary_authorization_resources ? 1 : 0

  name     = "${local.prefix}${var.kms_key_name}"
  key_ring = google_kms_key_ring.keyring[0].id
  purpose  = "ASYMMETRIC_SIGN"
  version_template {
    algorithm = var.kms_signing_alg
  }
  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      labels,
    ]
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "vulnz_attestor" {
  count         = local.create_binary_authorization_resources ? 1 : 0

  crypto_key_id = google_kms_crypto_key.vulnz_attestor_key[0].id
  role          = "roles/cloudkms.signer"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"

  lifecycle {
    prevent_destroy = true
  }
}

data "google_kms_crypto_key_version" "vulnz_attestor" {
  count      = local.create_binary_authorization_resources ? 1 : 0

  crypto_key = google_kms_crypto_key.vulnz_attestor_key[0].id
}

resource "google_binary_authorization_attestor" "vulnz_attestor" {
  count   = local.create_binary_authorization_resources ? 1 : 0

  project = google_container_analysis_note.vulnz_attestor[0].project
  name    = "${local.prefix}${var.vulnz_attestor_name}"
  attestation_authority_note {
    note_reference = google_container_analysis_note.vulnz_attestor[0].name
    public_keys {
      id = data.google_kms_crypto_key_version.vulnz_attestor[0].id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.vulnz_attestor[0].public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.vulnz_attestor[0].public_key[0].algorithm
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_binary_authorization_policy" "policy" {
  count                         = local.create_binary_authorization_resources ? 1 : 0

  project                       = google_container_analysis_note.vulnz_attestor[0].project
  global_policy_evaluation_mode = "ENABLE"
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.vulnz_attestor[0].id
    ]
  }
  dynamic "cluster_admission_rules" {
    for_each = local.cluster_details

    content {
      cluster          = "${cluster_admission_rules.value.parsed[0]}.${cluster_admission_rules.value.parsed[1]}"
      evaluation_mode  = var.stages[cluster_admission_rules.key].binary_authorization_evaluation_mode
      enforcement_mode = var.stages[cluster_admission_rules.key].binary_authorization_enforcement_mode
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
