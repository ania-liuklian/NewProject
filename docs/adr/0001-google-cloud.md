# ADR 0001 · Google Cloud services for Meetings

**Status:** Accepted for the lab. The Google Cloud deployment is designed for the no-account submission.

| AWS baseline or lab candidate | Decision | Google Cloud design |
| --- | --- | --- |
| S3 and CloudFront (pay-as-you-go) | Replace | Firebase Hosting serves the Vite build over HTTPS and sends deep links to the SPA. The AWS baseline has no WAF. |
| Lambda and function URL | Replace | Cloud Run serves the FastAPI container on `PORT`, scales to zero, and accepts Cognito bearer tokens at application level. |
| ECR | Replace | Artifact Registry stores the backend image. |
| Aurora PostgreSQL | Replace | Cloud SQL PostgreSQL 17, Enterprise `db-f1-micro` with 10 GB SSD. Start with an empty database and run the existing Alembic migrations. |
| DynamoDB | Drop | Meetings uses PostgreSQL. Firestore would require redesigning relational queries, ownership and participant data, and the migration workflow. |
| Cognito and optional Google sign-in | Keep | Keep the existing user pool. Cloud Run validates Cognito ID tokens. Migrating identity is outside the core port. |
| EventBridge Scheduler | Drop | The current app has no scheduled report. |
| SQS | Drop | The current app has no queue. |
| S3 events and Lambda | Drop | The current app has no event-triggered file processing. |
| SES | Drop | Account verification is handled by Cognito. The app sends no separate mail, so it needs no email-provider API key. If a report is added later, keep SES behind an AWS role or put any external provider key in Secret Manager. |
| Bedrock | Drop | The current app has no agenda parser to move to Vertex AI. |
| SSM Parameter Store | Replace | Secret Manager contains the generated Cloud SQL connection URL. |
| CloudWatch Logs | Replace | Cloud Run sends application logs to Cloud Logging. |
| IAM roles | Replace | A dedicated Cloud Run service account can connect to Cloud SQL and read just the database secret. User ADC is used for local deployment. CI could use repository-scoped Workload Identity Federation. |
| AWS infrastructure as code | Keep and add | The existing AWS configuration uses CloudFormation. Google Cloud has its own Terraform root and state. |

Cloud Run and Cloud SQL are in the same region, so the API's database traffic stays in that region. Running Cloud SQL continuously gives predictable availability and a recurring compute charge. Stopping it outside class saves compute while the app's database-dependent routes are unavailable, and disk charges continue. Firestore removes the idle instance charge but changes the schema and access code. Keeping Aurora would preserve PostgreSQL but add cross-cloud network latency, connectivity work, possible egress charges and Aurora resume delays.

Existing Cognito identities stay on AWS. A fresh lab database starts with an empty meeting history. Moving existing data would require a separate PostgreSQL export and import.
