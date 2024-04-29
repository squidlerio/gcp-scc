import argparse
import os
from google.cloud import securitycenter
import json
import sys
import requests
import logging
from flask import Flask, request, jsonify

# Initialize logging
logging.basicConfig(level=logging.WARNING)

def parse_arguments():
    parser = argparse.ArgumentParser(description='Generate Slack message payload for Security Center findings.')
    parser.add_argument('--projects', nargs='*', help='List of project IDs (overrides environment variable if provided)')
    parser.add_argument('--ignore-medium-low', action='store_true', help='Ignore medium and low severity findings')
    parser.add_argument('--slack-webhook', default=os.getenv('SLACK_WEBHOOK'))
    parser.add_argument('--log_level', default=os.getenv('LOG_LEVEL', 'WARNING'))
    return parser.parse_args()

def process_findings(project_ids, ignore_medium_low):
    client = securitycenter.SecurityCenterClient()

    if not project_ids or project_ids == ['']:
        raise ValueError("Error: No project IDs provided. Set them as an argument or through the SCC_PROJECT_IDS environment variable.")

    vulnerability_filter = f'(severity="CRITICAL" OR severity="HIGH" OR severity="MEDIUM" OR severity="LOW") AND state="ACTIVE" AND NOT mute="MUTED"'

    slack_message_blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "Security Command Center Findings"
            }
        }
    ]

    project_findings = []
    for project_id in project_ids:
        project_name = f"projects/{project_id}/sources/-"
        findings_result_iterator = client.list_findings(
            request={"parent": project_name, "filter": vulnerability_filter}
        )

        severity_count = {}
        for finding in findings_result_iterator:
            severity = finding.finding.severity
            if ignore_medium_low and (severity == 'MEDIUM' or severity == 'LOW'):
                continue
            severity_count[severity] = severity_count.get(severity, 0) + 1

        if not severity_count:
            continue

        Severity = securitycenter.Finding.Severity
        # Prepare severity counts
        critical_count = severity_count.get(Severity.CRITICAL, 0)
        high_count = severity_count.get(Severity.HIGH, 0)
        medium_count = severity_count.get(Severity.MEDIUM, 0)
        low_count = severity_count.get(Severity.LOW, 0)

        # Skip medium and low severities
        if ignore_medium_low and (severity == Severity.MEDIUM or severity == Severity.LOW) and high_count==0 and critical_count==0:
             continue
        # Format severity summary
        critical = f"C:{critical_count}, "
        high = f"H:{high_count}, "
        medium = f"M:{medium_count}, "
        low = f"L:{low_count}"

        severity_summary = f"{critical}{high}{medium}{low}"

        # Add warning symbol if critical or high count is greater than 0
        if (critical_count > 0 or high_count > 0):
            severity_summary += " :warning:"

        project_findings.append(f"*<https://console.cloud.google.com/security/command-center/overview?project={project_id}|{project_id}>*: {severity_summary}\n")


    if project_findings:
        slack_message_blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": '\n'.join(project_findings)
            }
        })

    return slack_message_blocks

def send_slack_message(slack_webhook, slack_payload):
    response = requests.post(slack_webhook, json=slack_payload)
    response.raise_for_status()
    logging.info("Slack message sent successfully.")




def burger_me(event):
    projects =  os.getenv('SCC_PROJECT_IDS', '').split(',')
    ignore_medium_low = os.getenv('IGNORE_MEDIUM_LOW', False)
    slack_webhook = os.getenv('SLACK_WEBHOOK')
    slack_blocks = process_findings(projects, ignore_medium_low)
    slack_payload = {"blocks": slack_blocks}
    if slack_webhook:
        send_slack_message(slack_webhook, slack_payload)
        return jsonify({"status": "success", "message": "Slack message sent successfully."}), 200
    else:
        return jsonify(slack_payload), 200

if __name__ == "__main__":
    args = parse_arguments()
    logging.getLogger().setLevel(args.log_level.upper())
    slack_blocks = process_findings(args.projects if args.projects else os.getenv('SCC_PROJECT_IDS', '').split(','), args.ignore_medium_low)
    slack_payload = {"blocks": slack_blocks}
    if args.slack_webhook:
        send_slack_message(args.slack_webhook, slack_payload)
    else:
        print(json.dumps(slack_payload, indent=4))
