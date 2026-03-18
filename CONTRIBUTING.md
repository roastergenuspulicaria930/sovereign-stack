# Contributing to Sovereign Stack

Thanks for wanting to help people take back their digital lives!

## How to contribute

1. **Fork** this repo
2. **Create a branch** for your change: `git checkout -b fix/phase2-firefox`
3. **Make your changes** — keep it simple and focused
4. **Test** your scripts on a fresh Ubuntu 24.04 install (VM is fine)
5. **Submit a PR** with a clear description of what you changed and why

## What we need help with

- Testing scripts on different Linux distros (Fedora, Arch, openSUSE)
- Translations (Portuguese, Spanish, French, German)
- Better documentation for non-technical users
- New app alternatives and comparisons
- Security audits of the Phase 4/5 scripts
- GrapheneOS setup guide
- Video tutorials for each phase

## Guidelines

- Scripts must work on a **fresh** Ubuntu 22.04/24.04 install
- Use `set -euo pipefail` in all bash scripts
- Don't add services that phone home or have telemetry
- Keep the language simple — this is for everyone, not just developers
- Test before submitting

## Code of Conduct

Be kind. We're all here because we believe privacy is a right.
