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

The existing backend, database, frontend, network and ECR stacks remain managed by CloudFormation. The Terraform root in [`infra/`](infra/) is the Lab 7 migration root: it adopts Cognito, weekly reports and the agenda parser. It reads the existing backend/frontend stack outputs, deployed Lambda image URIs and database password from SSM so those resources stay in place. The Terraform state is stored in [HCP Terraform](https://app.terraform.io).

For the course workflow, connect the HCP Terraform workspace to the GitHub repository and the
branch you submit. Set its working directory to `infra/` and use remote execution. Configure AWS
dynamic credentials (OIDC) for the workspace, and set `google_client_secret`,
`cloudflare_account_id`, and `cloudflare_api_token` as sensitive workspace variables. Also set
the report sender/recipient and other non-secret Terraform variables in the workspace. Do not
commit `.env`, Terraform state, or secret values.

`make tf-init` connects local Terraform CLI operations to the HCP state. `make infra-plan` is a
read-only preview. There is deliberately no `terraform apply` target in the Makefile: review PR
plans and apply from the HCP run page after merge.

### Labs 4–7 infrastructure migration

Cognito, weekly reports, and the agenda parser are described in Terraform modules under
`infra/modules/`; the former CloudFormation templates have been removed. `infra/imports.tf`
records the account-specific import IDs for the retained resources. The HCP import run and its
follow-up clean plan are still required before this migration is complete.

The retained CloudFormation stacks must be deleted only after their resources have
`DeletionPolicy: Retain` and `UpdateReplacePolicy: Retain` applied. Import each retained resource
into its matching Terraform address in HCP Terraform. Keep correcting configuration until the
import plan shows imports only (zero adds, changes, or destroys). Apply that plan in HCP, run a
new plan, and confirm it ends with:

```text
No changes. Your infrastructure matches the configuration.
```

The resource IDs are account-specific; see [the import checklist](docs/terraform-imports.md).
After the clean plan, remove `infra/imports.tf`. Never apply a plan that replaces the Cognito
user pool or reports bucket. Any resources intentionally created fresh instead of imported must
be deleted from the old stack safely first and recorded in the migration notes.

The migration root deliberately leaves the backend/database, frontend, network and ECR stacks
in CloudFormation and reads their outputs as data. The HCP workspace's `aws_region` must match
the region in `infra/imports.tf` (`eu-central-1` for the current IDs).

For the screenshot, open a PR with a harmless Terraform change, review the HCP speculative plan
check, merge it, then open the VCS-triggered run in HCP Terraform. When it says `Apply finished`,
capture the run page with its commit/trigger visible. The final plan output is a separate artifact
from immediately after import.

Requires Terraform and AWS credentials through HCP dynamic credentials. `make infra-lint` checks
formatting and configuration.

### Cognito sign-in and Google OAuth

`/login` immediately redirects signed-out visitors to **Amazon Cognito Managed Login**. Cognito
provides email/password sign-in, self sign-up and (when configured) Google sign-in. After
authentication Cognito returns to `/login`; the app reads the ID token and sends the user to
their meetings. Self sign-up is explicitly enabled in the Cognito Terraform module.

#### Create and publish the Google OAuth app

1. Open [Google Cloud Console](https://console.cloud.google.com/) and select or create a project
   for this app. Make sure you have permission to edit its OAuth configuration.
2. Open **Google Auth Platform → Branding** (called **OAuth consent screen** in some Console
   layouts). Set the app name, a support email, and developer contact email. For **Audience**,
   choose **External** so accounts outside your Google Workspace can sign in. Fill in the required
   contact/branding fields and save. The app only asks Google for the basic `openid`, `email`, and
   `profile` identity scopes; it does not request access to Calendar or other Google APIs.
3. Open **Google Auth Platform → Clients → Create client**. Choose **Web application**, give it a
   name, and under **Authorized redirect URIs** add exactly:

   ```text
   https://<COGNITO_DOMAIN>/oauth2/idpresponse
   ```

   Here `<COGNITO_DOMAIN>` is the Cognito domain created by this repo, without `https://` or a
   trailing slash. With the default settings it is
   `<PROJECT_NAME>-<AWS_ACCOUNT_ID>.auth.<AWS_REGION>.amazoncognito.com`; for example, if
   `PROJECT_NAME=meetings`, AWS account ID is `123456789012`, and region is `us-east-1`, use
   `https://meetings-123456789012.auth.us-east-1.amazoncognito.com/oauth2/idpresponse`.
   The AWS account ID is the 12-digit ID shown in the AWS Console account menu. Leave
   In **Authorized JavaScript origins**, also add the Cognito origin without a path, for example
   `https://meetings-123456789012.auth.us-east-1.amazoncognito.com`. Do not use the app's `/login`
   URL as Google's redirect URI.
4. Create the client and copy its **Client ID** and **Client secret**. Keep the secret private;
   Cognito uses it server-side. Put both values in the project-root `.env` (never commit this
   file):

   ```dotenv
   GOOGLE_CLIENT_ID=<Google Client ID>
   GOOGLE_CLIENT_SECRET=<Google Client secret>
   ```

5. In **Google Auth Platform → Audience**, click **Publish app** (or **Make external users
   available**, depending on the Console wording) and confirm. Check that the publishing status
   reads **In production** before submitting the assignment. `Testing` can limit who may sign in.
   This app requests only basic identity scopes, which generally do not require sensitive-scope
   verification; production publishing and Google's app verification are separate statuses. If
   Google prompts for branding verification, complete the requested project/app details.

#### Deploy Cognito and the site

1. Configure the AWS values in `.env` as described above in **Deploy to AWS**. The same
   `PROJECT_NAME` and `AWS_REGION` determine the Cognito domain used in Google's redirect URI.
2. Apply infrastructure changes through the reviewed HCP Terraform workspace run. The Terraform
   outputs contain the Cognito IDs/domain; copy the public values to `.env` for local frontend
   development when needed.

Google's callback is always the Cognito domain's `/oauth2/idpresponse`; Cognito's app-client
callback is the site URL plus `/login`. These are two different redirects, and both must be
configured at their respective providers.

### Custom domain

Set `domain_name` and `hosted_zone_id` in the HCP workspace variables:

```sh
DOMAIN_NAME=app.example.com
HOSTED_ZONE_ID=Z0123456789ABC   # optional: only if the domain's DNS is in Route 53
```

This requests an ACM certificate in `us-east-1` (the only region CloudFront accepts) and adds the domain to the CloudFront distribution, backend CORS origins, and Cognito redirect URLs. With `hosted_zone_id`, validation and alias records are created in Route 53. Without it, add the validation CNAME at your DNS provider when the HCP run pauses. Submit domain changes through the reviewed HCP workspace workflow.

### Tags

Every AWS resource that supports tags is tagged `PROJECT_NAME=<PROJECT_NAME>` (the AWS provider's `default_tags`). Find the whole app with Resource Groups & Tag Editor, and split out its costs in Billing once `PROJECT_NAME` is activated as a cost allocation tag.

## Layout

```
backend/    FastAPI app (app/), Alembic migrations (alembic/), tests (tests/)
frontend/   Vite + React + shadcn/ui (src/components/ui is generated by shadcn)
infra/      Terraform configuration for AWS (modules/: auth, backend, frontend)
```
