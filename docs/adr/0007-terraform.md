# ADR 0007: Terraform and HCP Terraform for infrastructure

- Status: Accepted for the course migration; imports and HCP VCS execution remain to be completed.
- Date: 2026-10-30

## Context

The application's Cognito sign-in, weekly reports, and agenda parser were described in separate
CloudFormation templates. The team needs reviewed plans, centralized state, and repeatable
environments without deleting Cognito users or saved report files.

## Decision

Use Terraform for the AWS infrastructure and HCP Terraform for remote state and VCS-triggered
runs. Connect a workspace to the repository and submitted branch with `infra/` as its working
directory. Use AWS dynamic credentials through OIDC. Review PR plans and apply through HCP after
merge. Store secret inputs as sensitive HCP workspace variables. Import resources before removing
the retained CloudFormation stacks/templates.

## Alternatives

- **CloudFormation:** AWS-native and keeps state inside AWS, but less convenient for a shared
  workflow across environments and providers.
- **AWS CDK:** offers a programming language interface but still synthesizes CloudFormation.
- **OpenTofu:** compatible open-source alternative; this lab uses Terraform/HCP Terraform to
  practice the managed VCS workflow.

## Consequences

- HCP state can contain secret values, so restrict access. Sensitive variables mask display but
  do not remove secrets from state.
- Cognito users and report objects must be retained during handoff. Never apply a plan that
  replaces the user pool or reports bucket.
- If HCP is unavailable, changes wait; recovery uses the HCP state and a reviewed run rather than
  creating a second local state.
- Backend image and frontend builds currently use local provisioners. Remote runs that trigger
  them need a configured HCP agent with Docker, Node.js, and AWS CLI, or those steps should move
  to a CI pipeline.
