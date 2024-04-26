output "workflow_name" {
  description = "Name of the deployed Google Cloud Workflow."
  value       = google_workflows_workflow.scc_slack_report_workflow.name
}

output "scc_slack_report_function_url" {
  description = "URL of the deployed add_iam_admin_role Cloud Function."
  value       = google_cloudfunctions2_function.scc_slack_report.service_config[0].uri
}

