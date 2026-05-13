# Contributing

Thank you for improving this deployment repository.

## Guidelines

- Keep examples generic and reusable.
- Use placeholders such as `example.com`, `CHANGE_ME`, and `noreply@example.com`.
- Do not add production secrets, private domains, private IP addresses, database files, or certificates.
- Update documentation when deployment behavior changes.
- Run the public safety check before opening a pull request.

```bash
./scripts/check-public-safe.sh
```

## Pull Requests

A good pull request includes:

- A concise summary
- Deployment or migration notes, when relevant
- Documentation updates for behavior changes
- Confirmation that the safety check passed

## Commit Messages

Use clear, descriptive commit messages.

Examples:

```text
Update smtp2brevo deployment notes
Add production checklist
Fix compose environment example
```
