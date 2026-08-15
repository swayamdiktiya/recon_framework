# Roadmap

This roadmap describes possible future improvements for Recon Framework. It is intentionally flexible as the framework evolves.

## Documentation

- [x] Public-facing README
- [x] Tool/dependency inventory
- [x] Installation guide
- [x] Scan coverage reference
- [x] Architecture documentation
- [ ] Add sanitized example reports
- [ ] Add terminal screenshots
- [ ] Add contributor/development guide

## Framework improvements

- [ ] Add a first-class dependency installer/bootstrapper
- [ ] Improve dependency version detection
- [ ] Add clearer optional-vs-required dependency classification
- [ ] Improve scan resumption/checkpoint support
- [ ] Improve per-step timing and performance reporting
- [ ] Add richer machine-readable output schemas
- [ ] Add HTML report generation
- [ ] Add configurable severity filtering

## Detection quality

- [ ] Continue reducing false positives
- [ ] Expand evidence-based confirmation helpers
- [ ] Improve authenticated scan coverage
- [ ] Expand business-logic checks
- [ ] Expand cloud-provider coverage
- [ ] Improve JavaScript and API analysis

## Engineering

- [ ] Add automated shell linting
- [ ] Add regression tests for core helper functions
- [ ] Add CI validation for Bash syntax and documentation
- [ ] Add compatibility testing across supported Linux distributions
- [ ] Document minimum versions for critical dependencies

## Community

- [ ] Add contribution guidelines
- [ ] Add issue templates
- [ ] Add security-reporting policy
- [ ] Publish a stable release/tag

## Guiding principles

1. **Authorization first** — scanning should be performed only within an approved scope.
2. **Evidence over noise** — prefer confirmed evidence over weak signatures.
3. **Modularity** — checks should remain independently selectable and maintainable.
4. **Transparency** — document external dependencies and limitations.
5. **Reproducibility** — make scan configuration and output easy to understand.
