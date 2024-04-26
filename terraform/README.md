
# Cloud Function Setup Module

This module sets up a Google Cloud Function, a topic and a cloud scheduled task
to automatically downgrade owners to iam admins periodically.

## Usage

```hcl
terraform {
  required_providers {
    google = {
      version = "~> 4.64"
    }
  }

  backend "gcs" {
    bucket="terraform-bucket"
  }
}

provider "google" {
  project = var.project
  region  = var.region
}

variable "project" {
  description = "The GCP project ID"
  type        = string
  default     = "my-gcp-project"  
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "europe-west1"  
}

variable "webhook" {
  type        = string
}

variable "projects" {
  type        = string
}
module "my_workflow" {
  source = "./terraform"
  source_bucket_name = "scc-slack-report-bucket"
  bucket_location = "EU"
  project_id = var.project
  slack_webhook_url = var.webhook
  scc_project_ids = var.projects
}
```