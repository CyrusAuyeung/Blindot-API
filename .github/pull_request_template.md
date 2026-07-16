# Pull Request

## Summary

Describe the outcome and why it is needed.

## Risk And Compatibility

Describe operator-visible changes, migration requirements, and rollback constraints. Write `None` when not applicable.

## Validation

List the checks and tests that were run.

## Checklist

- [ ] No production secret, address, certificate, dump, or runtime data is included
- [ ] Documentation and examples are updated for behavior changes
- [ ] Relay checks and tests pass when relay code changed
- [ ] Compose rendering passes when deployment files changed
- [ ] `sh scripts/check-public-safe.sh` passes

## Notes

Add deployment, monitoring, or follow-up notes if needed. Pull requests must not deploy production.
