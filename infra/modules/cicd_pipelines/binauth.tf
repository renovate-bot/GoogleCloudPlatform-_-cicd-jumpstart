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
}

resource "google_container_analysis_note" "vulnz_attestor" {
  project = data.google_project.project.project_id
  name    = "${local.prefix}${var.vulnz_attestor_name}"
  attestation_authority {
    hint {
      human_readable_name = "Vulnerability Attestor"
    }
  }
}

resource "google_container_analysis_note_iam_member" "vulnz_attestor_services" {
  project = google_container_analysis_note.vulnz_attestor.project
  note    = google_container_analysis_note.vulnz_attestor.name
  role    = "roles/containeranalysis.notes.occurrences.viewer"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-binaryauthorization.iam.gserviceaccount.com"
}

resource "google_kms_key_ring" "keyring" {
  project  = local.kms_project_id
  name     = "${local.prefix}${var.kms_keyring_name}"
  location = var.kms_keyring_location
}

resource "google_kms_crypto_key" "vulnz_attestor_key" {
  name     = "${local.prefix}${var.kms_key_name}"
  key_ring = google_kms_key_ring.keyring.id
  purpose  = "ASYMMETRIC_SIGN"
  version_template {
    algorithm = var.kms_signing_alg
  }
  labels = local.common_labels

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

resource "google_kms_crypto_key_iam_member" "vulnz_attestor" {
  crypto_key_id = google_kms_crypto_key.vulnz_attestor_key.id
  role          = "roles/cloudkms.signer"
  member        = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudbuild.iam.gserviceaccount.com"
}

data "google_kms_crypto_key_version" "vulnz_attestor" {
  crypto_key = google_kms_crypto_key.vulnz_attestor_key.id
}

resource "google_binary_authorization_attestor" "vulnz_attestor" {
  project = google_container_analysis_note.vulnz_attestor.project
  name    = "${local.prefix}${var.vulnz_attestor_name}"
  attestation_authority_note {
    note_reference = google_container_analysis_note.vulnz_attestor.name
    public_keys {
      id = data.google_kms_crypto_key_version.vulnz_attestor.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.vulnz_attestor.public_key[0].pem
        signature_algorithm = data.google_kms_crypto_key_version.vulnz_attestor.public_key[0].algorithm
      }
    }
  }
}

resource "google_binary_authorization_policy" "policy" {
  project                       = google_container_analysis_note.vulnz_attestor.project
  global_policy_evaluation_mode = "ENABLE"
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.vulnz_attestor.id
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
}
