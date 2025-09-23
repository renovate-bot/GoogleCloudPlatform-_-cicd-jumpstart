# Terraform Module establishing a CI/CD foundation (`cicd_foundation`)

This module provides a comprehensive CI/CD foundation on Google Cloud by
integrating CI/CD pipelines with managed development environments. It uses the
`cicd_pipelines` and `cicd_workstations` submodules to provision and configure:

*   **CI/CD Pipelines**: Sets up secure pipelines using Cloud Build, Artifact
    Registry, and Cloud Deploy for building, scanning, and deploying
    applications to Cloud Run or GKE. It also supports building custom images
    for Cloud Workstations, including scheduled rebuilds for patching.
*   **Managed Development Environments**: Sets up Cloud Workstations, allowing
    developers to use secure, pre-configured environments based on standard or
    custom images.

This foundation allows teams to automate application delivery and provide
developers with consistent and secure development environments.

## Features

*   Combines CI/CD pipelines for applications and Cloud Workstation custom
    images.
*   Provides managed Cloud Workstation environments via the `cicd_workstations`
    module.
*   Supports both Secure Source Manager and GitHub for triggering builds.
*   Includes security features like vulnerability scanning and Binary
    Authorization.
*   Allows scheduling of Cloud Workstation image rebuilds for security patching.

## Usage

Below is an example that sets up:
1.  A CI/CD pipeline for a Cloud Run application `my-app-1`.
2.  A CI/CD pipeline for a custom Cloud Workstation image `ide-1`, with a
    scheduled rebuild.
3.  A Cloud Workstation cluster and configuration using the custom `ide-1`
    image.

```terraform
module "cicd_foundation" {
  source = "../cicd_foundation"

  project_id = "your-gcp-project-id"

  # Application to be deployed to Cloud Run
  apps = {
    my-app-1 = {
      runtime = "cloudrun"
      stages = {
        dev = {}
      }
    }
  }

  # Custom image for Cloud Workstations
  cws_custom_images = {
    ide-1 = {
      workstation_config = {
        ci_schedule      = "0 1 * * *" # Rebuild daily
        scheduler_region = "us-central1"
      }
    }
  }

  # Cloud Workstation cluster definition
  cws_clusters = {
    "us-central1-cluster" = {
      region     = "us-central1"
      network    = "projects/your-gcp-project-id/global/networks/default"
      subnetwork = "projects/your-gcp-project-id/regions/us-central1/subnetworks/default"
    }
  }

  # Cloud Workstation configuration using the custom image
  cws_configs = {
    "ide-1-config" = {
      cws_cluster                  = "us-central1-cluster"
      # Image name matches AR path: {region}-docker.pkg.dev/{project}/{ar_repo_name}/{image_name}
      image                        = "us-central1-docker.pkg.dev/your-gcp-project-id/cicd-foundation/ide-1:latest"
      persistent_disk_type         = "pd-standard"
      persistent_disk_reclaim_policy = "DELETE"
      creators = [
        "group:your-dev-group@example.com",
      ]
    }
  }
}
```

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.6 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 6.11.0 |
| <a name="requirement_google-beta"></a> [google-beta](#requirement\_google-beta) | >= 6.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | >= 6.11.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cicd_pipelines"></a> [cicd\_pipelines](#module\_cicd\_pipelines) | ./cicd_pipelines | n/a |
| <a name="module_project_services"></a> [project\_services](#module\_project\_services) | terraform-google-modules/project-factory/google//modules/project_services | 18.0.0 |
| <a name="module_project_services_cloud_resourcemanager"></a> [project\_services\_cloud\_resourcemanager](#module\_project\_services\_cloud\_resourcemanager) | terraform-google-modules/project-factory/google//modules/project_services | 18.0.0 |
| <a name="module_workstations"></a> [workstations](#module\_workstations) | ./cicd_workstations | n/a |

## Resources

| Name | Type |
|------|------|
| [google_artifact_registry_repository_iam_member.workstation_artifactregistry_reader](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository_iam_member) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_apps"></a> [apps](#input\_apps) | Map of applications to be deployed. | <pre>map(object({<br/>    build = optional(object({<br/>      # The relative path to the Dockerfile within the repository.<br/>      dockerfile_path = optional(string)<br/>      # The timeout for the build in seconds.<br/>      timeout_seconds = number<br/>      # The machine type to use for the build.<br/>      machine_type = string<br/>      })<br/>    )<br/>    runtime = optional(string, "cloudrun"),<br/>    stages  = optional(map(map(string)))<br/>  }))</pre> | `{}` | no |
| <a name="input_artifact_registry_id"></a> [artifact\_registry\_id](#input\_artifact\_registry\_id) | The ID of an existing Docker Artifact Registry to use. If null, a new one will be created. | `string` | `null` | no |
| <a name="input_artifact_registry_name"></a> [artifact\_registry\_name](#input\_artifact\_registry\_name) | The name of the Artifact Registry repository to create if artifact\_registry\_id is null. | `string` | `"cicd-foundation"` | no |
| <a name="input_artifact_registry_region"></a> [artifact\_registry\_region](#input\_artifact\_registry\_region) | The region for Artifact Registry. | `string` | `"us-central1"` | no |
| <a name="input_cloud_build_api_key_display_name"></a> [cloud\_build\_api\_key\_display\_name](#input\_cloud\_build\_api\_key\_display\_name) | The display name of the API key for Cloud Build. | `string` | `"API key for Cloud Build"` | no |
| <a name="input_cloud_build_api_key_name"></a> [cloud\_build\_api\_key\_name](#input\_cloud\_build\_api\_key\_name) | The name of the API key for Cloud Build.<br/>You can import an existing API key by specifying its name here<br/>and running `terraform import`. | `string` | `"cloudbuild"` | no |
| <a name="input_cloud_build_region"></a> [cloud\_build\_region](#input\_cloud\_build\_region) | The region for Cloud Build. | `string` | `"us-central1"` | no |
| <a name="input_cws_clusters"></a> [cws\_clusters](#input\_cws\_clusters) | A map of Cloud Workstation clusters to create. The key of the map is used as the unique ID for the cluster. | <pre>map(object({<br/>    network    = string<br/>    region     = string<br/>    subnetwork = string<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_configs"></a> [cws\_configs](#input\_cws\_configs) | A map of Cloud Workstation configurations. | <pre>map(object({<br/>    cws_cluster                     = string<br/>    idle_timeout_seconds            = optional(number, 7200)<br/>    machine_type                    = optional(string, "n1-standard-96")<br/>    boot_disk_size_gb               = optional(number, 2000)<br/>    disable_public_ip_addresses     = optional(bool, false)<br/>    pool_size                       = optional(number, 0)<br/>    enable_nested_virtualization    = optional(bool, true)<br/>    persistent_disk_size_gb         = optional(number)<br/>    persistent_disk_fs_type         = optional(string)<br/>    persistent_disk_type            = string<br/>    persistent_disk_reclaim_policy  = string<br/>    persistent_disk_source_snapshot = optional(string)<br/>    image                           = optional(string)<br/>    # In case custom images shall be used, the keys from the cws_custom_images map.<br/>    custom_image_names = optional(list(string), [])<br/>    creators           = optional(list(string))<br/>    display_name       = optional(string)<br/>    instances = optional(list(object({<br/>      name         = string<br/>      display_name = optional(string)<br/>      users        = list(string)<br/>    })))<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_custom_images"></a> [cws\_custom\_images](#input\_cws\_custom\_images) | Map of applications as found within the apps/ folder of the repository,<br/>their build configuration, runtime, deployment stages and parameters. | <pre>map(object({<br/>    build = optional(object({<br/>      dockerfile_path = optional(string)<br/>      timeout_seconds = number<br/>      machine_type    = string<br/>      })<br/>    )<br/>    workstation_config = optional(object({<br/>      scheduler_region = string<br/>      ci_schedule      = string<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_image_build_runner_role_create"></a> [cws\_image\_build\_runner\_role\_create](#input\_cws\_image\_build\_runner\_role\_create) | Whether to create the custom IAM role for the Cloud Workstation Image Build Runner. If false, the role is expected to exist. | `bool` | `true` | no |
| <a name="input_cws_image_build_runner_role_id"></a> [cws\_image\_build\_runner\_role\_id](#input\_cws\_image\_build\_runner\_role\_id) | The role\_id for the custom IAM role for the Cloud Workstation Image Build Runner. | `string` | `"cwsBuildRunner"` | no |
| <a name="input_cws_image_build_runner_role_title"></a> [cws\_image\_build\_runner\_role\_title](#input\_cws\_image\_build\_runner\_role\_title) | The title for the custom IAM role for the Cloud Workstation Image Build Runner. | `string` | `"Cloud Workstation Image Build Runner"` | no |
| <a name="input_enable_apis"></a> [enable\_apis](#input\_enable\_apis) | Whether to enable the required APIs for the module. | `bool` | `true` | no |
| <a name="input_git_branch_trigger"></a> [git\_branch\_trigger](#input\_git\_branch\_trigger) | The Secure Source Manager (SSM) branch that triggers Cloud Build on push. | `string` | `"main"` | no |
| <a name="input_git_branches_regexp_trigger"></a> [git\_branches\_regexp\_trigger](#input\_git\_branches\_regexp\_trigger) | A regular expression to match GitHub branches that trigger Cloud Build on push. | `string` | `"^main$"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | The owner of the GitHub repository (user or organization). | `string` | `null` | no |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | The name of the GitHub repository. | `string` | `null` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Common labels to be applied to resources. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project-ID that references existing project. | `string` | n/a | yes |
| <a name="input_secret_manager_region"></a> [secret\_manager\_region](#input\_secret\_manager\_region) | The region for Secret Manager. | `string` | `"us-central1"` | no |
| <a name="input_secure_source_manager_always_create"></a> [secure\_source\_manager\_always\_create](#input\_secure\_source\_manager\_always\_create) | If true, create Secure Source Manager resources (instance, repository). These resources can be created even when a GitHub repository is also specified as the trigger source. | `bool` | `false` | no |
| <a name="input_secure_source_manager_deletion_policy"></a> [secure\_source\_manager\_deletion\_policy](#input\_secure\_source\_manager\_deletion\_policy) | The deletion policy for the Secure Source Manager instance and repository. One of DELETE, PREVENT, or ABANDON. | `string` | `"PREVENT"` | no |
| <a name="input_secure_source_manager_instance_id"></a> [secure\_source\_manager\_instance\_id](#input\_secure\_source\_manager\_instance\_id) | The full ID of an existing Secure Source Manager instance. If null, a new one will be created. | `string` | `null` | no |
| <a name="input_secure_source_manager_instance_name"></a> [secure\_source\_manager\_instance\_name](#input\_secure\_source\_manager\_instance\_name) | The name of the Secure Source Manager instance to create, if secure\_source\_manager\_instance\_id is null. | `string` | `"cicd-foundation"` | no |
| <a name="input_secure_source_manager_region"></a> [secure\_source\_manager\_region](#input\_secure\_source\_manager\_region) | The region for the Secure Source Manager instance, cf. https://cloud.google.com/secure-source-manager/docs/locations. | `string` | `"us-central1"` | no |
| <a name="input_secure_source_manager_repo_name"></a> [secure\_source\_manager\_repo\_name](#input\_secure\_source\_manager\_repo\_name) | The name of the Secure Source Manager repository. | `string` | `"cicd-foundation"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_build_api_key_name"></a> [cloud\_build\_api\_key\_name](#output\_cloud\_build\_api\_key\_name) | The name of the Cloud Build API key. |
| <a name="output_cloud_build_trigger_github_connection_needed"></a> [cloud\_build\_trigger\_github\_connection\_needed](#output\_cloud\_build\_trigger\_github\_connection\_needed) | Instructions to connect GitHub repository if using GitHub source. |
| <a name="output_cloud_build_trigger_ids"></a> [cloud\_build\_trigger\_ids](#output\_cloud\_build\_trigger\_ids) | The full resource IDs of the Cloud Build triggers. |
| <a name="output_cloud_build_trigger_trigger_ids"></a> [cloud\_build\_trigger\_trigger\_ids](#output\_cloud\_build\_trigger\_trigger\_ids) | The unique short IDs of the Cloud Build triggers. |
| <a name="output_secure_source_manager_instance_git_http"></a> [secure\_source\_manager\_instance\_git\_http](#output\_secure\_source\_manager\_instance\_git\_http) | The Git HTTP URI of the created Secure Source Manager instance. |
| <a name="output_secure_source_manager_instance_git_ssh"></a> [secure\_source\_manager\_instance\_git\_ssh](#output\_secure\_source\_manager\_instance\_git\_ssh) | The Git SSH URI of the created Secure Source Manager instance. |
| <a name="output_secure_source_manager_instance_html"></a> [secure\_source\_manager\_instance\_html](#output\_secure\_source\_manager\_instance\_html) | The HTML hostname of the created Secure Source Manager instance. |
| <a name="output_secure_source_manager_repository_git_html"></a> [secure\_source\_manager\_repository\_git\_html](#output\_secure\_source\_manager\_repository\_git\_html) | The Git HTML URI of the created Secure Source Manager repository. |
| <a name="output_secure_source_manager_repository_git_https"></a> [secure\_source\_manager\_repository\_git\_https](#output\_secure\_source\_manager\_repository\_git\_https) | The Git HTTP URI of the created Secure Source Manager repository. |
| <a name="output_webhook_setup_instructions"></a> [webhook\_setup\_instructions](#output\_webhook\_setup\_instructions) | Instructions to set up the webhook trigger. |
| <a name="output_webhook_setup_instructions_display"></a> [webhook\_setup\_instructions\_display](#output\_webhook\_setup\_instructions\_display) | Instructions to set up the webhook trigger. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
