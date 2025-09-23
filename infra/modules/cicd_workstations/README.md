# Terraform Module for supporting Cloud Workstations with custom images (`cicd_workstations`)

This module provisions
[Google Cloud Workstations](https://cloud.google.com/workstations/docs/overview),
providing managed, secure, and customizable development environments on Google
Cloud.

It allows you to define and manage:

*   **Workstation Clusters**: The top-level resource that defines the region and
    network for your workstations.
*   **Workstation Configurations**: Templates that define workstation settings
    like machine type, disk size, pool size, idle timeouts, and crucially, the
    container image to use for the development environment. This allows using
    custom images built via CI/CD pipelines (e.g., using the `cicd_pipelines`
    module).
*   **Workstation Instances**: Specific workstation instances based on a
    configuration, with assigned users.
*   **IAM**: Permissions for users to create or use workstations.

## Features

*   **Managed Development Environments**: Sets up Cloud Workstations clusters,
    configurations, and individual workstation instances.
*   **Custom Images**: Easily specify custom container images for workstation
    configurations, allowing standardized and pre-configured development
    environments.
*   **Networking**: Configures workstation clusters within your VPC network and
    subnets.
*   **Persistent Storage**: Supports persistent disks for retaining user data
    and IDE state across sessions.
*   **IAM Integration**: Manages IAM policies to grant specific users or groups
    permissions to create or access workstations.
*   **Fine-Grained Configuration**: Control machine types, disk sizes, idle
    timeouts, pool sizes, and more.

## Usage

Below is a basic usage example. It defines one cluster in `us-central1` and one
workstation configuration that uses a custom image and grants access to a
specific user.

```terraform
module "cicd_workstations" {
  source = "../cicd_workstations"

  project_id = "your-gcp-project-id"

  cws_clusters = {
    "us-central1-cluster" = {
      region     = "us-central1"
      network    = "projects/your-gcp-project-id/global/networks/default"
      subnetwork = "projects/your-gcp-project-id/regions/us-central1/subnetworks/default"
    }
  }

  cws_configs = {
    "ide-1" = {
      cws_cluster                  = "us-central1-cluster"
      image                        = "us-central1-docker.pkg.dev/your-gcp-project-id/cicd-foundation/ide-1:latest"
      machine_type                 = "e2-standard-4"
      boot_disk_size_gb            = 50
      disable_public_ip_addresses  = true
      enable_nested_virtualization = false
      idle_timeout_seconds         = 7200
      pool_size                    = 1
      persistent_disk_type           = "pd-standard"
      persistent_disk_size_gb        = 200
      persistent_disk_reclaim_policy = "DELETE"
      creators = [
        "group:your-dev-group@example.com",
      ]
      instances = [
        {
          name  = "developer-1-instance"
          users = ["user:developer-1@example.com"]
        }
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
| <a name="provider_google-beta"></a> [google-beta](#provider\_google-beta) | >= 6.11.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cws_service_account"></a> [cws\_service\_account](#module\_cws\_service\_account) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account | v40.1.0 |
| <a name="module_project_services"></a> [project\_services](#module\_project\_services) | terraform-google-modules/project-factory/google//modules/project_services | 18.0.0 |
| <a name="module_project_services_cloud_resourcemanager"></a> [project\_services\_cloud\_resourcemanager](#module\_project\_services\_cloud\_resourcemanager) | terraform-google-modules/project-factory/google//modules/project_services | 18.0.0 |

## Resources

| Name | Type |
|------|------|
| [google-beta_google_workstations_workstation.workstation](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_workstations_workstation) | resource |
| [google-beta_google_workstations_workstation_cluster.cluster](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_workstations_workstation_cluster) | resource |
| [google-beta_google_workstations_workstation_config.config](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_workstations_workstation_config) | resource |
| [google-beta_google_workstations_workstation_config_iam_policy.creators](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_workstations_workstation_config_iam_policy) | resource |
| [google-beta_google_workstations_workstation_iam_policy.iam_policies](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/google_workstations_workstation_iam_policy) | resource |
| [google_project_iam_member.workstations_operation_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_iam_policy.creators](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy) | data source |
| [google_iam_policy.users](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/iam_policy) | data source |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cws_clusters"></a> [cws\_clusters](#input\_cws\_clusters) | A map of Cloud Workstation clusters to create. The key of the map is used as the unique ID for the cluster. | <pre>map(object({<br/>    network    = string<br/>    region     = string<br/>    subnetwork = string<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_configs"></a> [cws\_configs](#input\_cws\_configs) | A map of Cloud Workstation configurations. | <pre>map(object({<br/>    # go/keep-sorted start<br/>    boot_disk_size_gb            = number<br/>    creators                     = optional(list(string))<br/>    cws_cluster                  = string<br/>    disable_public_ip_addresses  = bool<br/>    display_name                 = optional(string)<br/>    enable_nested_virtualization = bool<br/>    idle_timeout_seconds         = number<br/>    image                        = optional(string)<br/>    instances = optional(list(object({<br/>      name         = string<br/>      display_name = optional(string)<br/>      users        = list(string)<br/>    })))<br/>    machine_type                    = string<br/>    persistent_disk_fs_type         = optional(string)<br/>    persistent_disk_reclaim_policy  = string<br/>    persistent_disk_size_gb         = optional(number)<br/>    persistent_disk_source_snapshot = optional(string)<br/>    persistent_disk_type            = string<br/>    pool_size                       = number<br/>    # go/keep-sorted end<br/>  }))</pre> | `{}` | no |
| <a name="input_cws_scopes"></a> [cws\_scopes](#input\_cws\_scopes) | The scope of the Cloud Workstations Service Account | `list(string)` | <pre>[<br/>  "https://www.googleapis.com/auth/cloud-platform"<br/>]</pre> | no |
| <a name="input_cws_service_account_name"></a> [cws\_service\_account\_name](#input\_cws\_service\_account\_name) | Name of the Cloud Workstations Service Account | `string` | `"workstations"` | no |
| <a name="input_enable_apis"></a> [enable\_apis](#input\_enable\_apis) | Whether to enable the required APIs for the module. | `bool` | `true` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Common labels to be applied to resources. | `map(string)` | `{}` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project-ID that references existing project for deploying Cloud Workstations. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cws_clusters"></a> [cws\_clusters](#output\_cws\_clusters) | A map of Cloud Workstation clusters, with their IDs and other attributes. |
| <a name="output_cws_configs"></a> [cws\_configs](#output\_cws\_configs) | A map of Cloud Workstation configurations, with their IDs and other attributes. |
| <a name="output_cws_instances"></a> [cws\_instances](#output\_cws\_instances) | A map of Cloud Workstation instances, with their IDs and other attributes. |
| <a name="output_cws_service_account_email"></a> [cws\_service\_account\_email](#output\_cws\_service\_account\_email) | The email address of the Cloud Workstations Service Account. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
