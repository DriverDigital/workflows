# Fleet operations — waves, pilots, and what the audit cannot see

How kit changes actually reach the fleet, and the traps that have bitten. The **authoritative
release sequence is [`README.md`](../README.md) → *Release + repin order*** — this document does not
restate it. What lives here is the operational knowledge around it: how a wave is executed, what a
pilot can and cannot prove, and where the drift detector is blind.

Written 2026-08-02 from the v1.7.0 → v1.11.0 waves.

---

## The fleet

**21 repo@branch pairs**, and the split matters because two different numbers are correct depending
on the question:

| Set | Size | What it is |
|---|---|---|
| **Repin-wave targets** | **21** | Every pair carrying any kit caller stub. What `tools/fleet-pin-audit.sh` enumerates, and what a pin-only wave must cover — miss one and `--stale` never reads clean. |
| **Full-kit targets** | **18** | Pairs carrying `claude.yml` *and* `bonsai-status-sync.yml`. Verified branch-by-branch across all 618 org branches: zero rows where one is present without the other, so a wave touching one can touch both. |
| **Difference** | **3** | `Team-Laird@develop`, `The-Gathery@develop`, `driver-bonsai-mcp@main` — stub rails only, neither full workflow. They still need the pin repin. |

Palmers contributes **8** of the 18 (one per country branch: `main`, `-au`, `-ca`, `-in`, `-ma`,
`-me`, `-sa`, `-uk`); the other 10 are single-branch repos including Avara.

**Avara is the only provisioned store repo** — the only pair carrying `shopify-tool-smoke.yml`, and
the only one whose `claude.yml` has a non-empty `SHOPIFY_STORE_NAME`.

---

## Waves are direct pushes, not PRs

Decided at the v1.7.0 wave (2026-07-31) and used for every wave since. A mechanical,
centrally-reviewed kit change is pushed **straight to each branch with `[skip ci]` in the commit
message**, rather than opening 21 PRs.

Why:

- **Zero review runs.** 21 PRs would each fire `pr-first-review` and burn quota on a change that was
  already reviewed centrally.
- **Zero theme deploys.** Recon found `develop`/`staging` deploy workflows on ~10 fleet branches that
  a bare push *would* have fired. `[skip ci]` suppresses them.
- Branch protection does not enforce for admins (`enforce_admins: false` fleet-wide), so the push
  lands as Maria without a review round-trip.

**Reserve PR waves for changes that genuinely want per-repo review.** A kit change that is
byte-identical everywhere does not.

`[skip ci]` suppresses workflow triggers but **not** GitHub's own "Dependabot Updates" scheduler —
seeing one of those fire after a wave is expected and benign.

> **Never write the literal token in a commit message that is not itself a wave.** GitHub scans the
> **whole** commit message, not just the subject line, so a commit that merely *describes* the
> technique suppresses its own CI. This bit the commit that first added this document: it explained
> the wave pattern in its body, and the resulting PR came back with **zero check runs** — not failed,
> not queued, simply absent, which reads exactly like a healthy PR whose checks have not started yet.
> Write it as `skip-ci` in prose, and if a PR ever reports no checks at all, grep the commit message
> before looking anywhere else.

### Execution shape

One atomic commit per branch via the Git Data API (blobs → tree → commit → ref patch), not one
commit per file. Per target:

1. `claude.yml` ← kit version, with the repo's own `SHOPIFY_STORE_NAME` restored.
2. `bonsai-status-sync.yml` ← kit stub, **whole-file replacement**.
3. The other five stubs ← **sed the pin line only**, so any per-repo edit survives.
4. `shopify-tool-smoke.yml` (Avara only) ← kit version, store handle restored.
5. `actionlint` every file about to be written, then commit `[skip ci]` and patch the ref.

Guards worth keeping in any wave script: assert no destination path is written twice, assert the
store handle survived, assert no stale pin remains, and dry-run the whole fleet before writing
anything.

---

## Three traps

**1. Same basename in both halves of the diff.** When a full workflow becomes a stub, the kit diff
carries `templates/github/<name>.yml` *and* `.github/workflows/<name>.yml`. The wave rewrites
`templates/github/` → `.github/workflows/`, so both collapse onto one destination. Apply them
blindly and the *reusable* can land in a client repo **as** the workflow — where it is
`workflow_call`-only, fires on nothing, and looks green. Assert no destination is touched twice.

**2. Pin hunks patch from a base the fleet was never on.** At v1.11.0 the kit diff patched from
`80c35fe` (v1.8.0) while every deployed stub held `a54c91e` (v1.9.0) — because v1.9.0 shipped
without a kit repin commit even though the wave repinned the fleet. No kit revision had *ever*
carried `a54c91e` in a pin line, so no diff base produced a matching `-` line and `git apply` would
have rejected all five files on target #1. **Sed the pin; don't patch it.**

**3. Per-repo state that must survive.** `SHOPIFY_STORE_NAME` in `claude.yml` and
`shopify-tool-smoke.yml`, and any Dependabot-bumped action pins. Surveyed at v1.11.0: the fleet's
`claude.yml` copies were byte-identical to the kit except Avara's store handle, and there was no
Dependabot drift — but survey, don't assume.

---

## What the pin audit checks — and the one thing it still cannot see

`tools/fleet-pin-audit.sh` used to grep only
`DriverDigital/workflows/.github/workflows/<name>@<sha>` and compare that SHA to the latest tag,
which left three holes. Two of them let the v1.9.0 gap read green for a day. All three are now
checked; the script runs them in this order and exits non-zero if any fires:

1. **Reference** — every `uses:` pin in `templates/github/*.yml` equals the latest tag's SHA.
   Checks 2 and 3 measure the fleet *against* `templates/`, so a stale reference makes both of them
   lie. This is the v1.9.0 failure exactly: the wave repinned the fleet to `a54c91e` while the kit's
   own stubs still said `80c35fe`, and an audit that only ever compared deployed pins to the latest
   tag called the fleet uniform throughout. When this fires, nothing below it means anything —
   fix step 2 of the README's release order first.
2. **Pins** — each deployed caller stub's `uses:` SHA vs that tag. The original check, unchanged.
3. **Content** — the whole waved file vs its `templates/github/` source, byte for byte. This is
   what closes the other two holes: a file with **no `uses:` line at all** (an unconverted 190-line
   copy of what is now a 66-line stub) is no longer invisible, and `DRIVER_AGENTS_REF` — a raw SHA
   in an `env:` block that no bot can bump — is now compared like any other line.

Two things worth knowing about check 3:

- **Only `SHOPIFY_STORE_NAME` is normalized away.** It is the one difference a correctly-waved repo
  is *supposed* to have. Everything else that differs is reported, third-party action pins included:
  a repo whose Dependabot bumped `actions/checkout` past the kit's pin is drift worth seeing, and it
  means the kit is behind, not that the repo is wrong.
- **`DriverDigital/workflows` itself is skipped.** Its `.github/workflows/` holds the *reusables*,
  which share basenames with the stubs that call them — `pr-first-review.yml` is a ~200-line
  reusable there and a 25-line stub in the kit — so comparing it against `templates/` would report
  six phantom drifts.

**Still unchecked: the tripwire parity between `templates/` and canonical.** The audit proves the
fleet matches `templates/github/claude.yml`; it cannot prove that file's `--append-system-prompt`
blockquote still matches driver-agents `docs/agent-instructions-shopify.md` at the pinned
`DRIVER_AGENTS_REF`. That comparison is by hand, at release time — step 1 of the release order.

---

## Piloting a cross-repo reusable

The v1.11.0 pilot proved `vars.BONSAI_URL` resolves against the **caller**, so a per-repo tunnel
override still works after conversion. Two things made it harder than expected, both worth knowing
before designing the next one.

**The `issues` leg is not pilotable.** `bonsai-status-sync`'s issues gate greps the issue body for
`@claude`, and `claude.yml`'s issues gate does the same — deliberately mirrored. Any issue that
trips the status flip also wakes a real implementer run on a client repo. Use the PR leg.

**`closingIssuesReferences` only populates for PRs targeting the default branch.** A PR into a
scratch base dodges the theme-deploy workflows (they filter on `branches: [staging, dev-staging]`)
but resolves `uuid=<none>`, so the run never reaches the `curl` and passes green having tested
nothing. If the assertion needs the network call, the PR must target the default branch.

**Split the legs by what each can actually prove.** Leg 1 on a private consumer
(`foundrae-blackridge@staging`) proves a private repo resolves the public cross-repo reusable and
reads the caller's event payload — that is the visibility question. Variable resolution is
repo-agnostic, so leg 2 belongs wherever it is cheapest: `vite-plugin-shopify-clean` is public,
single-branch, and has no Shopify store attached, so nothing but node tests fire.

**Assert on the log line, not the colour.** Setting `BONSAI_URL` to a bogus host and checking for a
red run is not sufficient — a wrong-way resolution falls back to the hardcoded default and *also*
fails. The discriminator is which host the log names:

```
BONSAI_URL: https://pilot-bogus-host.invalid
curl: (6) Could not resolve host: pilot-bogus-host.invalid
```

Clean up afterwards: delete the variable, close the issue and PR, delete the scratch branches. Leave
the installed stub — the wave covers it anyway.

---

## Branch protection

`enforce_admins` is `false` fleet-wide, which is what makes direct-push waves work. Two live kit
branches have **no protection at all** — `studio-sulzer@main` and `Team-Laird@develop` (404 on the
protection endpoint). Every other kit branch is protected. The kit's onboarding steps assume a
human-approver rule exists, so on those two a bot signal alone could satisfy a merge.

On this repo, `main` requires **`actionlint`** (set 2026-08-02; before that `required_status_checks`
had `strict: true` but empty `contexts`, so `lint.yml` could report red without being able to block).
The context is the **job id** at `.github/workflows/lint.yml:28` — the workflow-level `name:` is not
part of it. Applied through the narrow sub-resource, never a whole-object `PUT`:

```bash
gh api -X PATCH repos/DriverDigital/workflows/branches/main/protection/required_status_checks \
  -f 'contexts[]=actionlint'
```

`PUT /branches/{branch}/protection` **replaces** the entire protection object, so any field left out
of the body is silently deleted — the 1-approval review rule included. The `PATCH` above touches
`required_status_checks` and nothing else; diffing the full object before and after confirmed only
`contexts`/`checks` moved. GitHub bound the context to the Actions app (`app_id: 15368`) on its own,
which is the stricter outcome: only a check run from Actions can satisfy it.

**`enforce_admins` stays `false` here — deliberately, and know what that buys.** With it `false`, an
admin can merge past *everything*: a red `actionlint`, no approval, `strict` or not. So requiring the
check does not make it unbypassable for Maria — it makes it unbypassable for everyone else, and it
puts a red X in front of an admin who would otherwise have had nothing to override. That is the
actual value, and it was worth having either way.

Flipping it to `true` was considered and rejected. The fleet-wide `false` exists because direct-push
repin waves depend on it, and that reasoning genuinely does *not* apply to this repo: no wave has ever
pushed here, and every commit on `main` is a PR merge. The reason to leave it alone anyway is
uniformity — one repo with a different admin rule is a thing to remember at exactly the wrong moment,
and the failure mode it would prevent (an admin knowingly merging red) is not one that has happened.
Revisit if it ever does.
