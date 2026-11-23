# Meetings App

List, create, and delete meetings with participants. FastAPI + PostgreSQL backend, React + shadcn/ui frontend, all run with Docker Compose. See [SPEC.md](SPEC.md) for the full specification.

## Quick start

Requires Docker.

```sh
make up      # creates .env from .env.example, builds and starts everything
make seed    # optional: sample participants and meetings
```

- App: http://localhost:3000
- API docs: http://localhost:8000/api/docs

If port 5432 is already in use on your machine, set `DB_PORT` in `.env` (e.g. `DB_PORT=5433`).

## Create a meeting with AI

**Create with AI** opens a dialog where you describe the meeting by typing or by voice, e.g. *"Sprint planning tomorrow 3–4pm in room 204 with Olena and Taras"*. The backend transcribes speech with OpenAI (`OPENAI_TRANSCRIPTION_MODEL`) and turns the text into form values with OpenAI structured outputs (`OPENAI_MODEL`). It resolves relative dates against your local time and matches people to existing participants. The result opens in the regular meeting form, and nothing is saved until you check it and click **Create meeting**.

Set `OPENAI_API_KEY` in `.env` and restart (`make restart`). Without a key the rest of the app works as usual and the assistant reports that it is not configured. Recordings are limited to 2 minutes.

## Common commands

Run `make` to list all targets. The most used:

| Command | What it does |
|---|---|
| `make up` / `make down` | Start / stop the stack |
| `make logs s=backend` | Follow logs of one service |
| `make test` | Backend tests (in the backend container, against `<db>_test`) |
| `make lint` / `make format` | Ruff + oxlint/Prettier |
| `make migration m="..."` | Autogenerate an Alembic migration |
| `make psql` | Open a psql shell |
| `make clean` | Stop and delete the database volume |

## Local development without rebuilding images

Requires [uv](https://docs.astral.sh/uv/) and Node.js.

```sh
make install        # uv sync + npm install
make dev-backend    # Postgres in Docker, API on :8000 with reload
make dev-frontend   # Vite on :5173, proxies /api to :8000
```

## Deploy to AWS

Everything is described with Terraform in [`infra/`](infra/) and deployed to `us-east-1` by default (`AWS_REGION` in `.env`). The state is stored in [HCP Terraform](https://app.terraform.io):

- **Backend** (`infra/modules/backend`): the backend container on AWS Lambda (via [Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter), so the FastAPI app runs unchanged), exposed through a public **Lambda function URL**, and its PostgreSQL 17 database on **Aurora Serverless v2 scaling between 0 and 1 ACU**. After 5 idle minutes the database pauses and costs only storage; the first request after that waits about 15 seconds while it resumes. The function runs in the database's private subnets; there is no NAT gateway, load balancer or public IP. The image is tagged with a hash of the backend sources and rebuilt only when they change.
- **Frontend** (`infra/modules/frontend`): the app, built with `VITE_API_URL` set to the function URL, in a private S3 bucket behind CloudFront on **pay-as-you-go** pricing (`PriceClass_100`). The browser calls the function URL directly; the CloudFront address (and custom domain) are the backend's CORS origins. It is rebuilt and uploaded only when its sources or settings change.
- **Auth** (`infra/modules/auth`): the Cognito user pool and app client.

1. In HCP Terraform, create an organization and a workspace named like `PROJECT_NAME` (CLI-driven workflow), and set the workspace's **Settings → General → Execution Mode** to **Local**: plans and applies run on your machine (they build the Docker image and the frontend), only the state is stored in HCP Terraform.
2. Put into `.env` the AWS credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) and the HCP Terraform settings (`TF_TOKEN_app_terraform_io`, `TF_CLOUD_ORGANIZATION`, optionally `TF_WORKSPACE`); see `.env.example`. `.env` is gitignored.
3. `make tf-init` once, then `make deploy`. It shows the plan, applies it after you confirm, writes the Cognito ids to `.env` (for local runs) and prints the app and API URLs. The first run takes about 20 minutes (database and CloudFront distribution). `make plan` only shows the changes.
4. `make destroy` deletes everything except the Cognito user pool (with its accounts) and a final database snapshot.

Requires Terraform, Docker, Node.js and the AWS CLI. `make infra-lint` checks the configuration.

### Custom domain

Set the domain in `.env` and run `make deploy`:

```sh
DOMAIN_NAME=app.example.com
HOSTED_ZONE_ID=Z0123456789ABC   # optional: only if the domain's DNS is in Route 53
```

This requests an ACM certificate in `us-east-1` (the only region CloudFront accepts) and adds the domain to the CloudFront distribution, the backend's CORS origins and Cognito's redirect URLs. With `HOSTED_ZONE_ID`, the validation and alias records are created in Route 53. Without it, `make deploy` first prints the validation CNAME to add at your DNS provider, waits for the certificate, and at the end prints the CNAME that points the domain at CloudFront. To remove or switch the domain, change `DOMAIN_NAME` and run `make deploy` again.

### Tags

Every AWS resource that supports tags is tagged `PROJECT_NAME=<PROJECT_NAME>` (the AWS provider's `default_tags`). Find the whole app with Resource Groups & Tag Editor, and split out its costs in Billing once `PROJECT_NAME` is activated as a cost allocation tag.

## Layout

```
backend/    FastAPI app (app/), Alembic migrations (alembic/), tests (tests/)
frontend/   Vite + React + shadcn/ui (src/components/ui is generated by shadcn)
infra/      Terraform configuration for AWS (modules/: auth, backend, frontend)
gcp/        Separate Terraform root and local Cloud Run demo configuration
```

## Lab 9 · Google Cloud

The [ADR](docs/adr/0001-google-cloud.md) maps the AWS services to Google Cloud. The [cost comparison](docs/lab9-costs.md) covers the four lab traffic profiles. Cognito stays on AWS. The Google Cloud database starts empty and the API runs the existing Alembic migrations.

### Run locally without a Google Cloud account

From the repository root, copy `.env.example` to `.env` if needed. In PowerShell:

```powershell
terraform -chdir=gcp init
terraform -chdir=gcp validate
docker compose -p meetings-lab9 -f docker-compose.yml -f gcp/compose.local.yml up -d --build backend
Invoke-RestMethod http://127.0.0.1:8080/api/health
npm.cmd --prefix frontend ci
$env:VITE_API_URL = ''
$env:VITE_API_PROXY = 'http://127.0.0.1:8080'
npm.cmd --prefix frontend run dev -- --host 127.0.0.1
```

Open `http://127.0.0.1:5173`. The health route executes `SELECT 1` on PostgreSQL. To test meeting data, set the existing Cognito user pool and client IDs in `.env`, restart the API and Vite, and sign in through an existing verified account. The lab Compose override builds the Cloud Run target, sets `PORT=8080` and runs the same image against the local PostgreSQL service.

See the [Terraform validation output](docs/lab9-terraform-output.txt) and [local demo screenshot](docs/lab9-local-demo.png).

Stop the lab containers with `docker compose -p meetings-lab9 -f docker-compose.yml -f gcp/compose.local.yml down`.

### Deploy to Google Cloud with billing enabled

Use a dedicated project, set up a billing budget alert, and run `gcloud auth application-default login`. The deploying identity needs permission to enable APIs, manage the resources in `gcp/`, create and attach the runtime service account, and grant its IAM permissions. Keep the state in a separate, access-controlled HCP Terraform workspace if using HCP. State contains the generated database credential, so keep state and plan files private. Local validation only needs provider downloads.

From the repo root, set `TF_VAR_project_id`, `TF_VAR_cognito_user_pool_id` and `TF_VAR_cognito_client_id` in the shell or set the corresponding Terraform variables in the workspace. First run `terraform -chdir=gcp apply` with `image_tag` unset. Then build and push the image before creating Cloud Run. For example, in PowerShell:

```powershell
$repo = terraform -chdir=gcp output -raw image_repository
gcloud auth configure-docker ($repo.Split('/')[0])
docker build --platform linux/amd64 --target cloud-run -t "${repo}:lab9-v1" backend
docker push "${repo}:lab9-v1"
$env:TF_VAR_image_tag = 'lab9-v1'
terraform -chdir=gcp apply
$env:VITE_API_URL = terraform -chdir=gcp output -raw api_url
$env:COGNITO_USER_POOL_ID = $env:TF_VAR_cognito_user_pool_id
$env:COGNITO_CLIENT_ID = $env:TF_VAR_cognito_client_id
npm.cmd --prefix frontend ci
npm.cmd --prefix frontend run build
firebase login
firebase deploy --only hosting --project $env:TF_VAR_project_id --config gcp/firebase.json
```

Use a unique image tag for each release. Confirm the Firebase URL loads, then sign in and verify that `GET /api/meetings` succeeds. If using Cognito's Google sign-in, add the Firebase URL's `/login` callback to the existing Cognito app client.

To pause Cloud SQL, set Terraform's `database_running` to `false` and apply. Database-backed requests will fail until it restarts, and storage charges continue. To remove the lab resources, run `terraform -chdir=gcp destroy` with the same variables and state. Firebase project enablement and enabled APIs can remain on the underlying Google Cloud project.
