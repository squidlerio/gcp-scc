variable "scc_slack_report_function_name" {
  description = "Name of the Cloud Function to report scc findings to slack."
  type        = string
  default     = "scc-slack-report-role-function"
}

variable "source_bucket_name" {
  description = "Name of the GCS bucket containing the zipped source code for the Cloud Functions."
  type        = string
}

variable "workflow_name" {
  description = "Name of the Google Cloud Workflow."
  type        = string
  default     = "scc-slack-report-workflow"
}

variable "workflow_region" {
  description = "Region where the Google Cloud Workflow will be deployed."
  type        = string
  default     = "europe-west1"
}

variable "project_id" {
  description = "The ID of the project in which resources will be deployed."
  type        = string
}


variable "bucket_location" {
  description = "Location where the GCS bucket will be created."
  type        = string
  default     = "EU"
}

variable "scheduler_frequency" {
  description = "Cron schedule for the Cloud Scheduler job."
  default     = "0 * * * *"
  type        = string
}

variable "slack_webhook_url" {
  description = "The Slack webhook URL for sending notifications"
  type        = string
}

variable "scc_project_ids" {
  description = "Comma-separated list of project IDs for the SCC findings"
  type        = string
}