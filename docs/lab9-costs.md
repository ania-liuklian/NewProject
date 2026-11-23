# Lab 9 · Meetings monthly cost comparison

USD per 730-hour month, before tax. AWS is in `us-east-1`, Google Cloud in `us-central1`. This is a list-price model, with rates from the lab and provider pricing pages. Calculator links below are the tools to reproduce the estimate.

| Piece | AWS assumption | GCP assumption |
| --- | --- | --- |
| Frontend, CDN and HTTPS | S3 Standard, 0.1 GB × $0.023 = $0.0023 before requests. CloudFront pay-as-you-go traffic is assumed within its free allowance. | Firebase Hosting within 10 GB storage and 360 MB/day transfer. |
| API | 512 MB Lambda. Up to 73,000 calls/month at 0.5 seconds per call, within Lambda request and compute allowances. | Cloud Run scales to zero and uses request-based billing. Up to 73,000 calls at 0.5 seconds, 1 vCPU and 512 MiB per call, within request, CPU and RAM allowances if startup and other billable time also fit. |
| Database compute | Aurora Standard at $0.12/ACU-hour. Estimate 0.5 ACU while awake and 0 ACU when paused. Include five minutes after each class demo or office day. | Cloud SQL shared-core at $0.0105/hour when running. Show continuous operation and a separate manual stop/start scenario. |
| Database storage | 1 GB × $0.10 = $0.10. Estimate four billed I/Os per API call at $0.20 per million. | 10 GB SSD × $0.17 = $1.70, including while stopped. |
| Registry, secrets and logs | One 0.5 GB ECR image at $0.10/GB. Standard SSM parameters and CloudWatch log volume within their allowances. | Up to 0.5 GB Artifact Registry storage, one active secret version, and low log volume within their allowances. |

Each active hour assumes 100 API calls, spread out enough to keep Aurora awake. Small S3 request charges, taxes, excess backups, network charges and free trial credits are excluded. Confirm actual image sizes and traffic before using the estimate as a budget.

| Profile | AWS Aurora awake hours | AWS total | GCP always on | GCP stopped outside use | Cheaper and why |
| --- | ---: | ---: | ---: | ---: | --- |
| Nobody | 0 | $0.15 | $9.37 | $1.70 | AWS. Aurora can pause and its storage allocation is smaller. |
| Class demos, 10 × 2 h | 20.83 | $1.40 | $9.37 | $1.91 | AWS. Aurora compute is charged only while awake, and Cloud SQL's 10 GB disk sets its floor. |
| Office hours, 8 h × 22 days | 177.83 | $10.84 | $9.37 | $3.55 | GCP. Aurora compute exceeds the Cloud SQL monthly compute charge. |
| Busy around the clock | 730 | $44.01 | $9.37 | $9.37 | GCP. The assumed Aurora rate while awake is $0.06/hour, versus $0.0105/hour for Cloud SQL. |

For example, office-hours AWS compute is `(176 + 22 × 5/60) × 0.5 × 0.12 = $10.67`, before storage, registry and I/O. GCP with scheduled uptime is `176 × 0.0105 + 1.70 = $3.55`. Start-up overlap is excluded on GCP. The busy row assumes the small Cloud SQL tier can handle the workload and compares monthly prices without claiming equal performance.

The GCP cost trap is leaving Cloud SQL running after Cloud Run scales to zero. In this model, that costs $7.67 in database compute every month, even with zero API requests. Stopping it leaves the $1.70 storage charge.

[AWS Pricing Calculator](https://calculator.aws/) · [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator) · [Aurora pricing](https://aws.amazon.com/rds/aurora/pricing/) · [Cloud SQL pricing](https://cloud.google.com/sql/pricing) · [Cloud Run pricing](https://cloud.google.com/run/pricing) · [Firebase pricing](https://firebase.google.com/pricing)
