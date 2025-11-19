# Copyright 2025 Google LLC
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

moved {
  from = google_container_analysis_note.vulnz_attestor
  to   = google_container_analysis_note.vulnz_attestor[0]
}

moved {
  from = google_container_analysis_note_iam_member.vulnz_attestor_services
  to   = google_container_analysis_note_iam_member.vulnz_attestor_services[0]
}

moved {
  from = google_kms_key_ring.keyring
  to   = google_kms_key_ring.keyring[0]
}

moved {
  from = google_kms_crypto_key.vulnz_attestor_key
  to   = google_kms_crypto_key.vulnz_attestor_key[0]
}

moved {
  from = google_kms_crypto_key_iam_member.vulnz_attestor
  to   = google_kms_crypto_key_iam_member.vulnz_attestor[0]
}

moved {
  from = google_binary_authorization_attestor.vulnz_attestor
  to   = google_binary_authorization_attestor.vulnz_attestor[0]
}

moved {
  from = google_binary_authorization_policy.policy
  to   = google_binary_authorization_policy.policy[0]
}
