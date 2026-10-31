# ADR 0007: Terraform and HCP Terraform for infrastructure

- Status: Accepted; retained-resource imports and HCP VCS execution remain to be completed.
- Date: 2026-10-30

## Context

The application's Cognito sign-in, weekly reports, and agenda parser were described in separate
CloudFormation templates. The team needs reviewed plans and centralized state without deleting
Cognito users or saved report files. The existing network, backend/database, frontend and ECR
stacks are already deployed by CloudFormation and are outside this migration's scope.

## Decision

Use Terraform for Cognito, weekly reports and the agenda parser, with HCP Terraform for remote
state and VCS-triggered runs. Keep the existing network, backend/database, frontend and ECR
stacks in CloudFormation; read their outputs and the database password from SSM as data sources.
Use AWS dynamic credentials through OIDC. Review PR plans and apply through HCP after merge. Store
secret inputs as sensitive HCP workspace variables. Adopt the retained resources with Terraform
imports before removing their old stack ownership. The import blocks remain in `infra/imports.tf`
until the import run succeeds and a subsequent plan is clean.

## Alternatives

- **CloudFormation only:** AWS-native and keeps state inside AWS, but does not provide the shared
  Terraform plan workflow chosen for these three stacks.
- **AWS CDK:** offers a programming language interface but still synthesizes CloudFormation.
- **OpenTofu:** compatible open-source alternative; this project chooses Terraform to use the
  existing HCP Terraform workspace and its managed VCS workflow.

## Consequences

- HCP state can contain secret values, so restrict access. Sensitive variables mask display but
  do not remove secrets from state.
- Cognito users and report objects must be retained during handoff. Never apply a plan that
  replaces the user pool or reports bucket.
- Terraform does not manage the pre-existing network, backend/database, frontend or ECR stacks;
  changes to their outputs must be coordinated with this migration workspace.
- If HCP is unavailable, managed runs and state operations wait. Restore service or use HCP's
  state recovery/export process before considering another backend; never initialize an
  uncoordinated local state and apply it against production.
