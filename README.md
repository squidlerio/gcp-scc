# GCP Security command center slack reporter

These scripts publish Security command center findings summaries to slack

## Sudo Script

The `sudo` script grants the user the `roles/owner` role for a specific GCP project. This allows the user to have elevated permissions and perform actions that might require owner-level access.

### Usage

```bash
python terraform/src/scc_slack_report/main.py --projects gcp-project1 gcp-project2  --ignore-medium-low --slack-webhook https://hooks.slack.com/services/dfasdfs4/dsafdsfdsafsdf
```
### Deploying using terraform
Can be deployed as cloud function and scheduled workflow

```bash
terraform apply -var "webhook=https://hooks.slack.com/services/TMEDJTBJ4/gfdsfggsdfg/dfhgdfghf" -var "projects=gcp-project1 gcp-project2"
```

* Remember to give the Service account that runs the cloud functions the role roles/securitycenter.findingsViewer on all projects it should report for. 

## Requirements
* Google Cloud SDK (gcloud command-line tool)
* Python 3
  
## Notes

* It's recommended to test these scripts in a non-production environment first.
