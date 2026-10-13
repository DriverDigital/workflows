# Branch model and the two platform standards

Driver sites are hosted on Shopify, Vercel or WordPress. Shopify and Vercel each have their own CI/CD
standard; WordPress has none, so its repos take the shared kit only. The shared kit (implementer,
Dependabot rails, lint, Bonsai link, PR template, house standards, `.claude/settings.json`,
`dependabot.yml`) is waved to enrolled repos. A platform's files go only to repos of that platform.

## Which repos get what

Four GitHub topics on each repo decide it. `tools/kit-platforms.sh` lists the files each platform adds.

| Topic | Means |
|---|---|
| `driver-kit` | The repo takes the kit. `tools/fleet-wave.sh` targets nothing without it, so a stale repo receives nothing further without being archived. |
| `shopify-theme` | A Shopify site: adds the Shopify files. |
| `vercel-site` | A Vercel site: adds the Vercel files. |
| `wordpress-site` | A WordPress site: no platform files, so the shared kit only. |

A repo carries at most one platform topic; the wave stops on a repo with two.

The platform topics describe the repo, and `driver-kit` opts it in, so a dormant theme can carry
`shopify-theme` and still receive nothing. The audit scans every repo regardless. It lists kit
workflow files on a repo without `driver-kit` in their own `unenrolled` section, which never fails the
audit, so a dormant repo keeps its old files until it is archived. A platform file on a repo of
another platform or of none is drift, and the wave refuses to write one there.

| Topics | Repos |
|---|---|
| `driver-kit` + `shopify-theme` | Avara, foundrae-blackridge, LaPointe, Kissy-Kissy, LittleMe, Palmers, R-Finds, savannahfriedkin, indie-ridge, Driver-Horizon, Anduril-Gear |
| `driver-kit` + `vercel-site` | Team-Laird, Driver-Digital-Website, studio-sulzer |
| `driver-kit` + `wordpress-site` | The-Gathery |
| `driver-kit` only | vite-plugin-shopify-clean, plugins, client-workspaces, driver-onboarding, driver-engineering-app, driver-agents |

driver-agents carries a partial kit (`templates/github/README.md`, *Partial install*) to keep the
dispatcher's repo separate from the rails it drives. Add a shared workflow there when it has a reason
to run in that repo.
Driver-Shopify-Eurus and Driver-Shopify-Prestige are archived and get nothing.

## The standards

| | Shopify sites | Vercel sites |
|---|---|---|
| Topic | `shopify-theme` | `vercel-site` |
| Long-lived branches | `main` only; Palmers keeps `main` plus `main-<country>` | `develop` (default, preview) and `main` (production) |
| Platform stub | `shopify-theme.yml` → reusable `shopify-theme.yml` | `vercel-deploy.yml` → reusable `vercel-deploy.yml` |
| What it deploys | PR preview `DRIVER/<head branch>`: checked while draft, pushed when ready, deleted on close. A push to `main`/`main-*` updates `DRIVER/<branch>`. Never a live theme, never published. | Each push to `main` or `develop` fires that branch's Vercel deploy hook, skipped for members of the Vercel team (Vercel's GitHub app has already deployed their push) |
| Secrets | `SHOPIFY_CLI_THEME_TOKEN`, and the store as `SHOPIFY_STORE` (or `SHOPIFY_FLAG_STORE`) | `VERCEL_DEPLOY_HOOK_MAIN`, `VERCEL_DEPLOY_HOOK_DEVELOP` |
| Variables | `SHOPIFY_ENVIRONMENT_PER_BRANCH=true` where store secrets live in one environment per branch (Palmers) | `VERCEL_TEAM_LOGINS`, per repo: space-separated GitHub logins with a seat on that project's Vercel team. When it's unset, `mcarter-astronautdev` alone is used |

Every long-lived branch, on every platform, requires branches to be up to date before merging
(`required_status_checks.strict: true`). Strict compares only against required checks, so it does
nothing on a branch with none: set it together with at least one required check (kit README, install
step 5). Enforcing it with an org ruleset or per repo is an open decision. How to set it per repo:
[fleet operations](fleet-operations.md#branch-protection).

An enrolled repo with no platform topic gets the shared kit only, as the tool repos do. The-Gathery
is a WordPress theme with `develop` + `main`; `wordpress-site` adds no files, so it too gets the
shared kit only.

No repo branch is ever connected to a store's live theme. Repos back unpublished preview themes
only, so a branch rename never touches a live storefront.

## Where branch names are hard-coded

This repo names branches only where a standard does. The two platform stubs filter on their
standard's branches (`main`/`main-*`; `main`/`develop`), `vercel-deploy.yml` tells production from
preview by `refs/heads/main` and `refs/heads/develop`, and `templates/github/lint.yml` runs on `push: [main]`.
Nothing else does: the implementer takes its base from the dispatcher's `Target branch:` line or the
repo default, the Dependabot reusables follow the PR, and the wave and the audit follow each repo's
default branch, plus every Palmers branch named `main*`. On a multi-branch repo (Palmers) the client
identifies the branch (a Palmers Morocco ticket is `main-ma`), and the dispatcher resolves it to the
map entry's branch; a `branch:` line on the ticket is
optional.

Elsewhere:

| Where | What names a branch |
|---|---|
| driver-agents `pipeline/project-repo-map.json` | `develop` for studio-sulzer, Avara, Driver-Digital-Website, LaPointe, LittleMe and Kissy-Kissy; `staging` for foundrae. The dispatcher writes the entry's branch on line 1 of every issue, and the implementer bases its branch and PR on it. driver-agents #55 moves the Shopify entries to `main`. Open issues filed before a cutover keep the old name. |
| Theme deploy workflows | Avara, LaPointe, Kissy-Kissy, LittleMe, R-Finds: `Feature-*` on PRs to `develop`, `Develop-Deploy` on push to `develop` → `DRIVER/develop` (Kissy-Kissy: `Kissy-2.0/develop`), and `Production-Deploy` on push to `main` (Avara, LaPointe, R-Finds; never run). foundrae: `Feature-*` and `Staging-Deploy` on `staging`/`dev-staging` → `DRIVER/<branch>`. The repos already on `main` carry `Feature-*` and `Staging-Deploy`. |
| Vercel `deploy.yml` | Team-Laird, Driver-Digital-Website: `refs/heads/main` → production hook, `refs/heads/develop` → preview hook, skipped for the Vercel team's logins (`mcarter-astronautdev`; Driver-Digital-Website also `jadewang425`). studio-sulzer has none. |
| Vercel project settings | Production branch and Team-Laird's custom `staging` environment, which follows `develop`. Set in Vercel, not in git. |
| `dependabot.yml` `target-branch: develop` | Team-Laird ×2, Driver-Digital-Website, studio-sulzer: redundant, since `develop` is the default. sandbox-vite-plugin-shopify-clean ×2 points at a branch that doesn't exist. The waved file sets none. |
| GitHub environments | foundrae: `staging`, `dev-staging`, `testparty/06-2026` hold the store secrets, picked by branch name. Palmers: one per branch. None of them has a deployment branch policy. |
| Protection | `develop` requires 1 review in Avara, LaPointe, Kissy-Kissy, LittleMe, R-Finds, The-Gathery, studio-sulzer, Driver-Digital-Website. `main` requires 0 in Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds and on every Palmers `main*` branch, and 1 in foundrae; every cutover repo's `main` has `allow_deletions` off. Driver-Horizon `main` and Team-Laird `develop` are unprotected. Up to date before merging is enforced (strict plus a required check) only on indie-ridge; foundrae `staging` and `main`, savannahfriedkin, studio-sulzer and Team-Laird `main` set strict with no required check, and the other site branches, all of Palmers' included, set neither. studio-sulzer's ruleset "Restrict main and develop" names both branches (disabled). |

## Shopify cutover, one repo at a time

**Repos to cut over:** Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds (from `develop`), and
foundrae-blackridge (from `staging`).

**Already on `main`:** Palmers, savannahfriedkin, indie-ridge, Driver-Horizon and Anduril-Gear. They
take steps 1, 5 and 6 only. Step 5's commit deletes their `Feature-*` and `Staging-Deploy` files;
until it does, indie-ridge's `lint.yml` reads red on their shellcheck findings. On Palmers the commit
lands on every `main*` branch, with `SHOPIFY_ENVIRONMENT_PER_BRANCH=true` set first. The store handle
the implementer and the smoke test use is the `SHOPIFY_STORE_NAME` repository variable, one per repo,
so a Palmers country branch cannot have its own.

**Before each cutover:**
- driver-agents' map names `main` for the repo.
- A repo with no build script passes `shopify theme check --fail-level error`, which its build job
  runs on every PR and push. Driver-Horizon fails it (`sections/header.liquid`, Driver-Horizon #10).
- No wave is running. The wave reads `default_branch` live, so one that runs mid-cutover commits to
  whichever branch is the default at that moment.

**Steps:**

1. **Read the repo's state before changing anything.**
   - Open PRs by base branch.
   - The commits only on `main`: `compare/<default>...main`. They are usually old "Update main with
     stable develop" promotions; read them anyway.
   - Open issues whose first line names the old branch.
   - Protection on both branches and environments.
2. **Rename the preview theme in the Shopify admin** from `DRIVER/develop` (or `Kissy-2.0/develop`,
   `DRIVER/staging`) to `DRIVER/main`. The first push then updates it in place instead of creating
   a new theme.
3. **Tag the old `main` and delete it.**
   - Tag it as `archive/main-<yyyy-mm>` through the API.
   - Retarget any PR whose base is `main` first, because GitHub closes PRs whose base branch is deleted.
   - Delete its protection (`DELETE repos/DriverDigital/<repo>/branches/main/protection`). Every
     cutover repo has `allow_deletions` off there, and the old rule would otherwise linger.
4. **Rename the working branch to `main`:** `POST repos/DriverDigital/<repo>/branches/<develop|staging>/rename`
   with `new_name=main`. GitHub retargets its open PRs, moves its protection rule and makes it the
   default. It does not touch workflow branch filters, Vercel or Dependabot settings, or rulesets
   (fix studio-sulzer-style rulesets by hand).
5. **Push one direct commit to `main`.** Leave `skip-ci` out, so the push deploys `DRIVER/main` and
   proves the stub. The commit:
   - deletes the old theme workflows (`Feature-*`, `Develop-Deploy`, `Staging-Deploy`, `Production-Deploy`,
     any lowercase variants)
   - adds the `shopify-theme.yml` stub
   - adds `.claude/settings.json` where the wave has not (repos without `claude.yml`)
   - adds the `@.github/claude-standards.md` import to `CLAUDE.md` where it's missing
6. **Check that it worked, and set protection.**
   - The push run created or updated `DRIVER/main`.
   - The open PRs now target `main`, and a ready PR deploys its preview.
   - `main` requires one review, the rule `develop`/`staging` carried.
   - `main` requires at least one check and up-to-date branches ([The standards](#the-standards)).
     The rename carries `develop`'s protection over, so a branch that lacked strict still lacks it.
     On Palmers, set it on every `main*` branch.
   - `tools/fleet-pin-audit.sh` shows the repo's row.
   - Close the repo's cutover to-do.
7. **Every clone,** each engineer's included. Check a local `main` for unpushed work first, since
   `-M` replaces it:
   `git fetch --prune origin && git branch -M <develop|staging> main && git branch -u origin/main main && git remote set-head origin -a`

**foundrae-blackridge also needs:**
- Its store secrets exist both at repo level and in the `staging` and `dev-staging` environments.
  Confirm the repo-level values point at the same store as `staging`'s, then leave
  `SHOPIFY_ENVIRONMENT_PER_BRANCH` unset. If they don't match, create a `main` environment holding
  `staging`'s secrets and set the variable.
- Decide whether `dev-staging` (stale) and `testparty/06-2026` stay or go.
- `main` is connected to the unpublished `foundrae/main` theme through Shopify's GitHub integration.
  Folding `staging` in syncs all of its commits to that theme, so look at the theme first.

## Vercel install, per site

No branch changes:

1. Confirm the repo carries `driver-kit` and `vercel-site`.
2. Confirm both hook secrets exist. studio-sulzer has no `deploy.yml`, so create its two hooks in
   Vercel first.
3. Set `VERCEL_TEAM_LOGINS` on the repo to the logins its current `deploy.yml` skips. That's
   `mcarter-astronautdev jadewang425` on Driver-Digital-Website; Team-Laird can stay on the
   fallback. A login left out deploys twice.
4. Push one direct commit to `develop`:
   - add the `vercel-deploy.yml` stub
   - delete `deploy.yml`
   - add `.claude/settings.json` where the wave has not (repos without `claude.yml`)
   - add the `@.github/claude-standards.md` import to `CLAUDE.md` where it's missing

   `main` picks the commit up at the next promotion. Until then, `main`'s own `deploy.yml` keeps
   working.
5. Require at least one check and up-to-date branches on both `develop` and `main`
   ([The standards](#the-standards)). Team-Laird's `develop` needs protection first.

driver-agents also deploys through Vercel, from `main` only. It is a tool, not a site, so it stays
outside this standard until it needs one.

## Order

1. Wave the shared kit first, with `--message`, because the default names the last tag. HANDOFF
   lists what rides it.
2. Canary the `shopify-theme.yml` stub on savannahfriedkin (steps 1, 5 and 6) and read its push job
   log. Then pilot the Shopify cutover on LittleMe: `main` is a strict ancestor
   of `develop`, it has few open PRs and two deploy files, and there is no production workflow. Then
   the rest, one at a time.
3. Vercel installs.
4. `tools/fleet-pin-audit.sh --stale` reads converged.
