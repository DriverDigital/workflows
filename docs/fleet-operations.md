# Fleet operations — waves, pilots, and what the audit cannot see

How kit changes reach the fleet, and the traps around it. The release sequence lives in
[`README.md`](../README.md#release--repin-order); this doc does not restate it. Which repos and
branches are targets is decided by topic ([`branch-model.md`](branch-model.md)); for the current
target list, run `tools/fleet-wave.sh --dry-run`.

---

## Waves are direct pushes, not PRs

A wave pushes one commit straight to each target branch, with the CI-skip token in the message.

- **No review spend.** A PR per target would spend a Macroscope review in every repo on a change
  already reviewed here.
- **No deploys.** Theme and Vercel deploy workflows fire on push to the branches a wave touches; the
  skip-ci token suppresses them.
- **No round-trip.** `enforce_admins` is `false` on every protected kit branch, so the push lands as an
  admin without approval.

Use a PR wave only for a change that wants per-repo review. A byte-identical kit change does not.

The skip-ci token does not stop GitHub's "Dependabot Updates" scheduler, so a run of it after a wave
is expected.

**Never write the literal token in a commit message that is not a wave.** GitHub scans the whole
message, body included, so a commit that only describes the technique skips its own CI. The PR then
shows no check runs at all, which looks like checks that have not started yet. Write `skip-ci` in
prose. If a PR reports no checks, grep its commit messages first.

### Execution shape

`tools/fleet-wave.sh`'s header owns discovery, what each target receives and the guards; read it
before a wave. What it cannot say:

- **One atomic commit per branch** through the Git Data API (blobs, tree, commit, ref patch), never
  one commit per file.
- **Deletes go in the same commit.** A tree entry with `sha: null` removes a path. Delete by
  presence (list the branch's files first), never from an assumed install list: partial installs are
  normal. Retire a rail by deleting its files the same way, never with `gh workflow disable`: the
  audit compares files and cannot see a disabled workflow.
- **Pass `--message` when no new tag is being waved.** The default message names the tag
  (`chore(kit): repin to <tag>`), which misdescribes a wave that carries only kit-file changes.
- **Plan from anywhere, push from `main`.** A dry run works from the branch that builds the change; a
  real wave runs only from a clean `main` that contains the tag.

### Three traps

1. **Same basename in both halves of a diff.** A reusable and its stub share a name
   (`.github/workflows/<name>.yml` and `templates/github/<name>.yml`). Both map to the same
   destination, and the reusable landing in a client repo is `workflow_call`-only, fires on nothing
   and looks green. The wave asserts no path is written twice; keep that guard in any script that
   moves kit files.
2. **Never patch a pin.** A diff patches from a base the fleet may never have held, so its `-` line
   matches nothing. Write the file whole from `templates/`, as the wave does.
3. **No per-repo state in a kit file.** The store handle is the `SHOPIFY_STORE_NAME` repository
   variable, and the wave refuses a target whose deployed file holds a handle the variable does not.
   A repo's Dependabot moving a kit action to a new major is drift for the wave to roll back, not
   state to keep.

---

## Dependabot and the wave

**The wave is the primary path; Dependabot is the backstop.** The wave repins every target within
minutes of a tag. Dependabot bumps the `DriverDigital/workflows` stub pins (SHA and `# vX.Y.Z`
trailer together) on a repo the wave skipped or could not reach, and between waves.

The kit's `dependabot.yml` variants (`templates/github/dependabot/`, picked by
`tools/kit-platforms.sh`) carry a daily `github-actions` block (weekly on driver-agents), and exempt `DriverDigital/workflows*`
from GitHub's default 3-day cooldown; each file's header says why. Two limits apply:

- **Only the default branch is updated.** The variants set no `target-branch`, so Palmers' country
  branches take pin moves from the wave alone.
- **A Dependabot PR needs a merge.** A wave is one direct push; a bump waits on a person.

To trigger a check by hand, comment `@dependabot recreate` on an open Dependabot PR, or use Insights →
Dependency graph → Dependabot → *Check for updates*. Read the job logs with
`gh run list --workflow "Dependabot Updates"`, then `gh run view <id> --log`. They show what
Dependabot saw and why it held a version.

To prove the backstop on a tag, wave with `--skip <repo>` on a repo whose `dependabot.yml` is
already its kit variant, then watch for the bump PR.

---

## What the pin audit cannot see

`tools/fleet-pin-audit.sh`'s header owns its three checks (reference, pins, content) and what it
normalizes. Run it after every wave; `--stale` must report converged. When the reference check
fires, nothing below it means anything: fix the kit repin first.

It does not compare **this repo**: its `.github/workflows/` holds the reusables, which share
basenames with the stubs, so the audit skips it. The Shopify blockquote is `lint.yml`'s job.

---

## Piloting a cross-repo reusable

A new rail that shares `claude.yml`'s trigger wakes a real implementer run on a client repo. Before
it ships fleet-wide, pilot it with these rules:

- **Pilot on the PR leg.** An issue that trips the new rail also trips the implementer's issues gate.
- **Target the default branch when the run needs the linked issue.** `closingIssuesReferences`
  resolves only for PRs into the default branch. A PR into a scratch base avoids deploy workflows but
  resolves no issue, so the run can skip its real work and pass green having tested nothing.
- **Split the legs by what each can prove.** A private consumer proves a private repo resolves the
  public reusable and reads the caller's event payload. Variable resolution is repo-agnostic, so run
  that leg wherever it is cheapest: a public, single-branch repo with no store attached
  (`vite-plugin-shopify-clean`).
- **Assert on the log line, not the colour.** A bogus variable value makes a wrong-way resolution
  fail too, because it falls back to a default. Check which value the log names, e.g.
  `curl: (6) Could not resolve host: pilot-bogus-host.invalid`.
- **Clean up.** Delete the pilot variable, close the issue and PR, and delete the scratch branches.
  Leave the installed stub; the wave covers it.

---

## Branch protection

**The standard, on every kit branch:**

- **A human approver.** `required_approving_review_count` of at least 1.
- **Branches up to date before merging.** `required_status_checks.strict: true`. Strict applies only
  against required checks, so it needs at least one: a check that runs on every PR: `validate / validate` where the repo carries `dependabot-validate`, else `actionlint` where it carries `lint.yml`. Never require a context the branch
  does not run; it blocks every merge.
- **`enforce_admins: false`.** Waves and this repo's releases are direct admin pushes.

**Edit an existing rule through its subresource with `PATCH`.** `PUT /branches/{branch}/protection`
replaces the whole object and silently drops every field left out of the body, the review rule
included:

```bash
gh api -X PATCH repos/DriverDigital/<repo>/branches/<branch>/protection/required_status_checks \
  -F strict=true -f 'contexts[]=validate / validate'
```

`PATCH` only edits a status-check rule that exists; a branch with none returns 404. Creating one takes
a `PUT` of the whole protection object, so read it first, carry every field into the body, and diff
it after.

The context is the job id, not the workflow's `name:`. GitHub binds it to the Actions app, so only an
Actions check run satisfies it. Diff the full protection object before and after any change.

`enforce_admins: false` means an admin can merge past a red check and a missing approval. A required
check still blocks everyone else, and puts a red X in front of the admin.

This repo's `main` meets the standard (`actionlint`, strict, one approval).

**The gap:** most kit branches lack strict with a required check, and a few have no protection or no
human approver. One org ruleset will enforce the up-to-date rule fleet-wide (#99);
the current state is in [`HANDOFF.md`](HANDOFF.md).

## Repository settings

Every active repo, under Settings → General → Pull Requests:

- **Merge commits on, squash off.** PRs land with a merge commit so each commit survives on `main`.
  Rebase stays on.
- **Allow auto-merge on.** It only permits auto-merge: a PR merges itself only after someone turns
  it on for that PR, and it still waits for the required checks and approval. The private forks
  (primavera-shopify-theme, shopify-metadata-app) ignore the setting.
- **Always suggest updating pull request branches on.**
- **Automatically delete head branches on every site repo** (one with a platform topic), except
  foundrae-blackridge, which keeps long-lived branches such as `dev-staging` and `testparty/*` that
  open PRs use as heads. Branch protection keeps a protected head branch, so merges between Palmers'
  `main*` branches are safe. The tool repos choose case by case.

```sh
gh api -X GET repos/DriverDigital/<repo> \
  -q '{allow_merge_commit,allow_squash_merge,allow_rebase_merge,allow_auto_merge,allow_update_branch,delete_branch_on_merge}'
```

Deleting other branches by hand: only a stale branch whose PR merged and that holds no commits past
that merge, so no one's work in progress goes. List them and get a yes first; never on foundrae.
