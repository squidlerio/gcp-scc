data "archive_file" "scc_slack_report_source_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src/scc_slack_report"
  output_path = "${path.module}/build/scc_slack_report.zip"
  excludes = ["*.terraform*"]
}

resource "google_storage_bucket" "source_bucket" {
  name     = var.source_bucket_name
  location = var.bucket_location
}

resource "google_storage_bucket_object" "scc_slack_report_source" {
  name   = "functions/scc_slack_report.zip"
  bucket = google_storage_bucket.source_bucket.name
  source = data.archive_file.scc_slack_report_source_zip.output_path
}

resource "google_service_account" "scc_slack_report_sa" {
  account_id   = "scc-slack-report"
  display_name = "Security command center slack report Service Account for Cloud Functions"
  description  = "This service account is used by the Cloud Functions to report security issues to slack."
}

resource "google_project_iam_member" "function_invoker" {
  project = var.project_id
  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}

resource "google_project_iam_member" "scc_slack_report_service_account_user" {
  project = var.project_id
  role   = "roles/iam.serviceAccountUser"
  member = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}

resource "google_project_iam_member" "security_center_viewer" {
  role   = "roles/securitycenter.findingsViewer"
  member = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
  project = var.project_id
}

resource "google_secret_manager_secret" "scc_report_slack_webhook" {
  secret_id = "scc-report-slack-webhook-url"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "scc_report_slack_webhook_version" {
  secret      = google_secret_manager_secret.scc_report_slack_webhook.id
  secret_data = var.slack_webhook_url
}

resource "google_secret_manager_secret_iam_member" "scc_slack_report_sa_secret_accessor" {
  secret_id = google_secret_manager_secret.scc_report_slack_webhook.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}


resource "google_cloudfunctions2_function" "scc_slack_report" {
  name        = var.scc_slack_report_function_name
  description = "Function to report SCC findings to Slack"
  location    = var.workflow_region

  build_config {
    runtime     = "python310"
    entry_point = "burger_me"
    source {
      storage_source {
        bucket = var.source_bucket_name
        object = google_storage_bucket_object.scc_slack_report_source.name
      }
    }
  }

  service_config {
    available_memory        = "128Mi"
    timeout_seconds         = 60
    ingress_settings        = "ALLOW_INTERNAL_ONLY"
    service_account_email   = google_service_account.scc_slack_report_sa.email

    environment_variables = {
      "SCC_PROJECT_IDS" = var.scc_project_ids
      "SLACK_WEBHOOK"   = "${google_secret_manager_secret_version.scc_report_slack_webhook_version.secret_data}"
    }
  }
}


resource "google_workflows_workflow" "scc_slack_report_workflow" {
  name     = var.workflow_name
  region   = var.workflow_region
  service_account = google_service_account.scc_slack_report_sa.email

  source_contents = <<-EOT
  - initialize:
      assign:
        - project: ${var.project_id}
        - scc_slack_report_function_url: ${google_cloudfunctions2_function.scc_slack_report.service_config[0].uri}
  - scc_slack_report:
      call: http.get
      args:
        url: ${google_cloudfunctions2_function.scc_slack_report.service_config[0].uri}
        auth:
          type: OIDC
          audience: ${google_cloudfunctions2_function.scc_slack_report.service_config[0].uri}
      result: scc_slack_report_result
  - final:
      return: "Workflow completed"
  EOT
}

resource "google_cloudfunctions2_function_iam_member" "scc_slack_report_invoker" {
  project = var.project_id
  cloud_function = google_cloudfunctions2_function.scc_slack_report.name
  location = var.workflow_region
  role   = "roles/cloudfunctions.invoker"
  member = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}

resource "google_cloud_run_v2_service_iam_member" "scc_slack_report_invoker" {
  project = var.project_id
  location = var.workflow_region
  name        =  google_cloudfunctions2_function.scc_slack_report.name
  role   = "roles/run.invoker"
  member = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}
resource "google_cloud_scheduler_job" "scc_slack_report_scheduler" {
  name             = "unsudo-scheduler"
  description      = "Scheduler to trigger the scc_slack_report workflow"
  schedule         = var.scheduler_frequency
  time_zone        = "UTC"
  attempt_deadline = "360s"

  http_target {
    http_method = "POST"
    uri         = "https://workflowexecutions.googleapis.com/v1/${google_workflows_workflow.scc_slack_report_workflow.id}/executions"
    oauth_token {
      service_account_email = google_service_account.scc_slack_report_sa.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }

    headers = {
      "Content-Type" = "application/octet-stream"
      "User-Agent"   = "Google-Cloud-Scheduler"
      # Add more headers as needed
    }

    body = base64encode(jsonencode({
      argument       = "{}",
      callLogLevel   = "LOG_ERRORS_ONLY"
    }))
  }
}

resource "google_project_iam_member" "workflow_invoker" {
  project = var.project_id
  role    = "roles/workflows.invoker"
  member  = "serviceAccount:${google_service_account.scc_slack_report_sa.email}"
}