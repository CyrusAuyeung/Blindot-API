# Contributing

Thank you for improving the Blindot API deployment repository.

## Repository Boundary

Changes here affect deployment definitions, operations documentation, and smtp2brevo. The Sub2API core source lives upstream and is consumed as a container image. Pull requests and CI must never deploy or mutate a production host.

## Guidelines

- Keep examples generic and reusable.
- Use placeholders such as `example.com`, `CHANGE_ME`, and `noreply@example.com`.
- Do not add production secrets, private addresses, environment files, certificates, dumps, or runtime data.
- Preserve persistent paths and document any operator migration step.
- Update documentation and tests when behavior changes.
- Keep changes scoped; avoid combining a runtime upgrade with unrelated tuning.

## Local Validation

```bash
sh scripts/check-public-safe.sh

cd smtp2brevo
npm ci --ignore-scripts
npm run check
npm test
npm audit --omit=dev
```

If Docker Compose is available, render the stack with sanitized temporary environment files and run `docker compose ... config --quiet`. Never overwrite an existing private `.env` during validation.

## Pull Requests

A good pull request includes:

- A concise outcome-focused summary
- Risk, compatibility, and rollback notes
- Documentation for operator-visible changes
- Tests or validation evidence
- Confirmation that no production data or secret is present

Use clear, descriptive commit messages such as:

```text
Harden smtp2brevo request limits
Document the Sub2API upgrade workflow
Validate Compose configuration in CI
```
