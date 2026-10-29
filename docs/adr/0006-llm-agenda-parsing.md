# ADR 0006: Cloudflare Workers AI agenda parsing

## Status

Accepted by the course instructor as an alternative provider.

## Context

Users paste meeting notes that need to become a structured, editable agenda. The text is untrusted, model output can be wrong, and inference has a metered price and free daily allowance.

## Decision

Use `@cf/meta/llama-3.3-70b-instruct-fp8-fast` through Cloudflare's OpenAI-compatible Workers AI Chat Completions API with JSON mode. Keep the authenticated parser in a Lambda outside the VPC: it needs outbound HTTPS access but not Aurora. Keep the Cloudflare account ID and API token server-side in Lambda configuration; the token is never sent to the browser. Validate the returned JSON with Pydantic. The browser reviews and edits the suggestion; only the existing authenticated Meetings API writes it to Aurora. The Lambda role only needs CloudWatch Logs permissions, not Bedrock permissions.

## Alternatives considered

- Claude or Nova on Bedrock: the original and earlier implementation; replaced to use Cloudflare Workers AI.
- Gemini Free Tier: another external model service with its own quota and data terms.
- Browser-only rules: available as a fallback, but less capable on natural-language agendas.

## Consequences

Each successful parse is logged with user id, provider, model, prompt version, token counts when returned by the API, latency, and estimated on-demand cost. For the selected model, the estimate uses Cloudflare's published per-token rates; actual charges may be zero while usage is within the Workers AI free daily allocation. The free allocation is 10,000 Neurons per day; on the paid plan, usage above it is billed. The $5 monthly AWS budget alerts on AWS charges only and does not cap Cloudflare usage. If Cloudflare is unavailable or its free quota is exhausted, users can use local rules or type the agenda manually. Meeting save and the rest of the application continue to work.
