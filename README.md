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

Everything is described with CloudFormation in [`infra/`](infra/) and deployed to `us-east-1` by default (`AWS_REGION` in `.env`):

- **Backend** (`make deploy-backend`): the backend container on AWS Lambda (via [Lambda Web Adapter](https://github.com/awslabs/aws-lambda-web-adapter), so the FastAPI app runs unchanged), exposed through a public **Lambda function URL**, and its PostgreSQL 17 database on **Aurora Serverless v2 scaling between 0 and 1 ACU**. After 5 idle minutes the database pauses and costs only storage; the first request after that waits about 15 seconds while it resumes. The function runs in the database's private subnets; there is no NAT gateway, load balancer or public IP.
- **Frontend** (`make deploy-frontend`): the app, built with `VITE_API_URL` set to the function URL, in a private S3 bucket behind CloudFront on **pay-as-you-go** pricing (no flat-rate plan; `PriceClass_100`). The browser calls the function URL directly; the deploy adds the CloudFront address to the backend's CORS origins.

1. Put the credentials of an IAM user into `.env` (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`; see `.env.example` for the optional settings). `.env` is gitignored.
2. `make deploy` (backend, then frontend). It prints the app and API URLs. The first run takes about 20 minutes (database and CloudFront distribution); later runs take a few minutes. Deploy the two parts separately with `make deploy-backend` / `make deploy-frontend`.
3. `make destroy-frontend` and `make destroy-backend` delete everything except a final database snapshot.

Requires Docker, Node.js and the AWS CLI. `make infra-lint` checks the templates.

### Cognito sign-in and Google OAuth

`/login` immediately redirects signed-out visitors to **Amazon Cognito Managed Login**. Cognito
provides email/password sign-in, self sign-up and (when configured) Google sign-in. After
authentication Cognito returns to `/login`; the app reads the ID token and sends the user to
their meetings. Self sign-up is explicitly enabled in `infra/auth.yaml`.

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
2. Run `make deploy-auth`. This creates the user pool, email/password app client, Cognito domain,
   Managed Login v2 branding, and Google identity provider, then writes the public Cognito settings
   to `.env`. The deploy output should say `Google sign-in: enabled` and
   `COGNITO_GOOGLE_ENABLED=true`.
3. Run `make deploy` to deploy the backend and frontend. The frontend deploy adds the resulting
   CloudFront URL (and any configured custom domain) to Cognito's allowed callback URLs. Open
   `https://<your-site>/login`; Cognito should show email/password, a sign-up option, and **Continue
   with Google**. After sign-in the app header shows the user's email.

Google's callback is always the Cognito domain's `/oauth2/idpresponse`; Cognito's app-client
callback is the site URL plus `/login`. These are two different redirects, and both must be
configured at their respective providers.

### Custom domain

Once everything is deployed, set the domain in `.env` and attach it:

```sh
DOMAIN_NAME=app.example.com
HOSTED_ZONE_ID=Z0123456789ABC   # optional: only if the domain's DNS is in Route 53
```

```sh
make add-domain
```

This requests an ACM certificate in `us-east-1` (the only region CloudFront accepts), adds the domain to the CloudFront distribution and to the backend's CORS origins. With `HOSTED_ZONE_ID`, the validation and alias records are created in Route 53 for you. Without it, the command prints the validation CNAME to add at your DNS provider, waits for the certificate, and then prints the CNAME that points the domain at CloudFront. Later `make deploy` runs keep the domain. `make remove-domain` detaches it again (to switch domains: `make remove-domain`, change `DOMAIN_NAME`, `make add-domain`).

### Tags

Every AWS resource that supports tags is tagged `PROJECT_NAME=<PROJECT_NAME>` (in the templates as `Key: PROJECT_NAME, Value: !Ref ProjectName`, plus stack tags and tags on the SSM parameter). Find the whole app with Resource Groups & Tag Editor, and split out its costs in Billing once `PROJECT_NAME` is activated as a cost allocation tag. `APP_NAME` in older `.env` files still works as the project name.

## Layout

```
backend/    FastAPI app (app/), Alembic migrations (alembic/), tests (tests/)
frontend/   Vite + React + shadcn/ui (src/components/ui is generated by shadcn)
infra/      CloudFormation templates and deploy scripts for AWS
```
