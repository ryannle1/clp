# Changelog

## [1.0.0] — 2026-03-17

### Added
- Core CLP protocol with four-zone context model (kernel, active, working, buffer)
- 7 skills: status, checkpoint, handoff, doctor, plan, reset, setup
- 4 lifecycle hooks: SessionStart, UserPromptSubmit, PreCompact, SessionEnd
- XML-structured rules file for compaction-resilient context guidance
- Standalone bash installer with 7-step setup and merge support
- Diagnostic tool (clp-doctor) with 21 validation checks
- Integration test suite with 12 functional tests
- CI workflow for GitHub Actions
- Handoff manifest specification (JSON, versioned, machine-readable)
- Skill registry with trigger-keyword demand-loading
- Plugin marketplace manifest for /plugin install
- Full protocol specification document
