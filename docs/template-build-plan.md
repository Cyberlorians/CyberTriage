# Template Build Plan

This is the backlog for turning the current starter repo into a full customer-ready deployment package.

## Phase 1: Package Existing Working Flow

Status: started.

Tasks:

- Copy validated commercial Logic App templates.
- Copy Node SAS broker source.
- Copy Live Response wrapper.
- Write architecture docs.
- Write storage/SAS notes.
- Write permissions notes.
- Write operator runbook.
- Keep collector binary out of Git.

## Phase 2: Make Deployment Repeatable

Tasks:

- Add parameter files with fake/sample values only.
- Add script to deploy evidence storage.
- Add script to deploy Function host storage.
- Add script to deploy SAS broker Function.
- Add script to assign broker storage roles.
- Add script to deploy Logic Apps in order.
- Add script to output manual post-deploy steps.
- Add script to validate broker health.
- Add script to validate SAS generation without printing SAS.

## Phase 3: Permissions Automation

Tasks:

- Script role assignment for broker managed identity.
- Script role assignment for Logic App managed identities.
- Script MDE application role assignment if raw HTTP managed identity is used.
- Document which API connections still require portal authorization.
- Decide whether to replace WDATP connector actions with raw HTTP + managed identity.

## Phase 4: Commercial One-Click Deployment

Tasks:

- Push repo to GitHub.
- Add raw template URLs.
- Add Deploy to Azure buttons.
- Test in a clean commercial tenant.
- Record every permission prompt and post-deploy click.
- Add screenshots.

## Phase 5: GCCH Version

Tasks:

- Verify MDE GCCH endpoint and token audience.
- Verify Log Analytics and Sentinel endpoint behavior.
- Verify Logic App managed connector availability.
- Verify Azure Government Function hosting model.
- Verify storage DNS suffix and SAS broker behavior.
- Create tested GCCH templates or cloud parameter model.
- Add Deploy to Azure Government buttons only after validation.

## Phase 6: Customer-Facing Guide

Tasks:

- Add screenshots for each Azure portal step.
- Add one simple diagram for the full flow.
- Add one permissions diagram.
- Add a glossary for 9th grade reading level.
- Add troubleshooting examples.
- Add validation checklist.
- Add rollback steps.

## Open Questions

- Should production use public endpoint/default allow with shared keys disabled, or a private endpoint design?
- Should the MDE connector stay, or should all MDE calls use raw HTTP with managed identity?
- Should email notification be removed, fixed, or made optional?
- What retention/lifecycle policy should the evidence storage account use?
- What exact Cyber Triage collector redistribution rules apply for customer repos?
