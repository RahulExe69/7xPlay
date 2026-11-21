# 7xPlay Clean-Slate Presentation — Execution Ledger

**Plan:** docs/superpowers/plans/2026-11-21-7xplay-clean-slate-presentation.md  
**Design:** docs/superpowers/specs/2026-11-21-7xplay-clean-slate-presentation-design.md  
**Branch:** feat/clean-slate-presentation  
**Date:** 2026-11-21

## Workspace ruling

The current environment has no mounted 7xPlay checkout and no Flutter/Dart executable. A native Git worktree cannot be created here. GitHub clone access is unavailable from the container, but the connected GitHub repository API can create commits on an isolated feature branch, and GitHub Actions checks out the branch on a real Flutter 3.41.5 runner.

**Chosen execution method:** use the dedicated feature branch and its Draft PR as the isolated workspace; perform red/green verification through the repository's Android regression workflow. Do not describe this as a local worktree or claim local commands were run. This trades local iteration speed for remote, source-of-truth CI execution. Keep every test added to the workflow so it is actually executed.

## Cross-task interface preflight

- Task 3 is the only owner of ExperienceDestination, ExperienceTabController, ExperienceNavigation, ExperienceRoot and ExperienceRouteBuilders. Tasks 5 and 6 consume ExperienceRouteBuilders; they must not define competing screen factories.
- ExperienceRouteBuilders is a UI-only, context-free widget factory for already-resolved records/identifiers. DeepLinkRoutes retains record fetch/validation and MediaLinkNavigationService retains target parsing/dispatch.
- Task 7 owns PlayerPresentationState and PlayerPresentationCallbacks. Task 8 consumes the same player surface contract; do not create a second TV-only playback state machine.
- TvFocusMemory, TvScreenFocusController, TvBackDispatcher and DevicePresentationService remain the TV/runtime owners; new TV widgets adapt to these APIs rather than duplicating them.
- Five handheld destination IDs stay home, new, discover, search, mine; the display name Library must not rewrite persisted mine.
- FlixQuest remains the runtime/provider/lifecycle host until the new experience root is connected and validated. It is not removed as collateral cleanup.

## TDD evidence

### Task 2 — semantic palette contract

- RED run: https://github.com/RahulExe69/7xPlay/actions/runs/44928493934
- The regression job completed 18 earlier groups successfully, then failed at Test clean-slate experience palette roles because lib/experience/design/experience_palette.dart did not exist and ExperiencePalette was undefined.
- Expanded test coverage was committed before implementation in commit 0051975b3c77df14fcc8d964caa9cc7a7cd21b78. The next run must be used to verify the additional ThemeExtension import/access/interpolation cases fail for the expected missing implementation before green implementation is committed.
- Palette and primitive tests now pass on CI run 44930271864 (5 palette tests and 11 primitive behavior tests). The ARM64 debug APK build and artifact upload steps passed in that run. The final analyzer step reported only an unused import and deprecated test semantics API; both are being corrected in the next commit.

## Verification constraints

- Existing Android workflow uses Flutter 3.41.5 stable and includes a debug APK job.
- Maven Central returned HTTP 429 during the first baseline APK dependency resolution. A later attempt was cancelled by branch advancement before its build step completed. Record the next complete build result separately from regression-test results.
- Before any task is marked complete: inspect the actual GitHub job logs and exit/conclusion; run the required full test/analyze/build step on CI. Install/device checks require a real emulator/device and are not provided by this environment.

## Progress

| Task | Status |
|---|---|
| Task 1 — contract inventory | Initial runtime, navigation, external-link, TV-focus and player contracts recorded; full caller search remains required before legacy deletion |
| Task 2 — design foundation | Palette/theme and four shared primitives implemented; 5 palette tests + 11 widget tests green in CI. Analyzer cleanup in progress; APK artifact produced. |
| Tasks 3–9 | Not started |
