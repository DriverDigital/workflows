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
| Long-lived branches | `main` only; Palmers keeps `main` plus `main-<country>` | `main` only |
| Production | Publish a theme in the Shopify admin. No branch backs a live theme. | Promote a staged deployment in Vercel. No push reaches production. |
| Platform stub | `shopify-theme.yml` → reusable `shopify-theme.yml` | `vercel-deploy.yml` → reusable `vercel-deploy.yml` |
| What it deploys | PR preview `DRIVER/<head branch>`: checked while draft, pushed when ready, deleted on close. A push to `main`/`main-*` updates `DRIVER/<branch>`. Never a live theme, never published. | Each push to `main` fires the main deploy hook, skipped for members of the Vercel team (Vercel's GitHub app has already built their push). Either way the build is a staged production deployment. Vercel's GitHub app builds a preview for every open PR, whoever opens it. |
| Secrets | `SHOPIFY_CLI_THEME_TOKEN`, and the store as `SHOPIFY_STORE` (or `SHOPIFY_FLAG_STORE`) | `VERCEL_DEPLOY_HOOK_MAIN` |
| Variables | `SHOPIFY_ENVIRONMENT_PER_BRANCH=true` where store secrets live in one environment per branch (Palmers) | `VERCEL_TEAM_LOGINS`, per repo: space-separated GitHub logins with a seat on that project's Vercel team. When it's unset, `mcarter-astronautdev` alone is used |

On Vercel, `main` stays the project's production branch with "Auto-assign Custom Production
Domains" off (Settings → Environments → Production). A push builds with production environment
variables and data, which is what staging should show, and its own deployment URL is the staging
link. Promoting it (the deployment's Promote action, or `vercel promote <url>`) puts that exact build
live without rebuilding. Undoing an Instant Rollback (Undo Rollback, or `vercel promote` during a
rollback) turns auto-assign back on; turn it off again right after.

Every long-lived branch, on every platform, requires branches to be up to date before merging
(`required_status_checks.strict: true`). Strict compares only against required checks, so it does
nothing on a branch with none: set it together with at least one required check (kit README, install
step 5). One org ruleset will enforce it (#99). Until then, how to set it per repo:
[fleet operations](fleet-operations.md#branch-protection).

An enrolled repo with no platform topic gets the shared kit only, as the tool repos do. The-Gathery
is a WordPress theme with no deploy automation; `wordpress-site` adds no files, so it too gets the
shared kit only.

No repo branch is ever connected to a store's live theme. Repos back unpublished preview themes
only, so a branch rename never touches a live storefront.

## Where branch names are hard-coded

This repo names branches only where a standard does. The Shopify stub filters on `main`/`main-*`,
the Vercel stub on `main`, and `templates/github/lint.yml` runs on `push: [main]`. Nothing else does:
the implementer bases its branch and PR on the repo's default branch, or on the `Target branch:` line
the dispatcher writes when the ticket or its map entry names a branch (only Palmers' entries do); the Dependabot reusables follow the PR; and the wave and the
audit follow each repo's default branch, plus every Palmers branch named `main*`. On Palmers the
client identifies the branch (a Palmers Morocco ticket is `main-ma`), and the dispatcher resolves it
to the map entry's branch; a `branch:` line on the ticket is optional.

Elsewhere:

| Where | What names a branch |
|---|---|
| driver-agents `pipeline/project-repo-map.json` | Palmers only: `main` and each `main-<country>`. The dispatcher writes that branch on line 1 of the issue. No other entry names a branch, so a rename needs no map change. An open issue whose first line names `develop` or `staging` (foundrae #193) keeps it until edited. |
| Theme deploy workflows | Avara, Kissy-Kissy, LittleMe, R-Finds: `Feature-*` on PRs to `develop`, `Develop-Deploy` on push to `develop` → `DRIVER/develop` (Kissy-Kissy: `Kissy-2.0/develop`), and `Production-Deploy` on push to `main` (Avara, R-Finds). LaPointe has the same set in lowercase: `feature-deploy`, `feature-build-test`, `development-deploy`, `production-deploy`. foundrae: `Feature-*` and `Staging-Deploy` on `staging`/`dev-staging` → `DRIVER/<branch>`. The repos already on `main` carry `Feature-*` and `Staging-Deploy`. |
| Vercel `deploy.yml` | Team-Laird, Driver-Digital-Website: `refs/heads/main` → production hook, `refs/heads/develop` → preview hook, skipped for the Vercel team's logins (`mcarter-astronautdev`; Driver-Digital-Website also `jadewang425`). studio-sulzer has none. |
| Vercel project settings | Production branch `main`, with production domains auto-assigned, and Team-Laird's custom `staging` environment, which follows `develop`. Set in Vercel, not in git. |
| `dependabot.yml` `target-branch: develop` | Team-Laird ×2, Driver-Digital-Website, studio-sulzer: redundant, since `develop` is the default. sandbox-vite-plugin-shopify-clean ×2 points at a branch that doesn't exist. The waved file sets none. |
| GitHub environments | foundrae: `staging`, `dev-staging` and the `testparty/*` branches hold the store secrets, picked by branch name. Palmers: one per branch. None of them has a deployment branch policy. |
| Protection | `develop` requires 1 review in Avara, LaPointe, Kissy-Kissy, LittleMe, R-Finds, The-Gathery, studio-sulzer, Driver-Digital-Website. `main` requires 0 in Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds and on every Palmers `main*` branch, and 1 in foundrae; every cutover repo's `main` has `allow_deletions` off. Driver-Horizon `main` and Team-Laird `develop` are unprotected. Up to date before merging is enforced (strict plus a required check) only on indie-ridge; foundrae `staging` and `main`, savannahfriedkin, studio-sulzer and Team-Laird `main` set strict with no required check, and the other site branches, all of Palmers' included, set neither. studio-sulzer's ruleset "Restrict main and develop" names both branches (disabled). |

## Cutover, one repo at a time

The same steps serve both platforms: tag and delete the old `main`, then rename the working branch to
`main`, which keeps its open PRs and its protection. Merging it into `main` instead would close every
PR based on it.

**Shopify repos to cut over:** Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds (from `develop`),
and foundrae-blackridge (from `staging`).

**Vercel repos to cut over:** Driver-Digital-Website, studio-sulzer and Team-Laird (from `develop`).

**WordPress repo to cut over:** The-Gathery (from `develop`). Nothing in GitHub deploys it, so it
takes steps 1, 3, 4, 7 and 8 only.

**Shopify repos already on `main`:** Palmers, savannahfriedkin, indie-ridge, Driver-Horizon and
Anduril-Gear. They take steps 1, 6 and 7 only. Step 6's commit deletes their `Feature-*` and
`Staging-Deploy` files. On Palmers the commit lands on every `main*` branch, with
`SHOPIFY_ENVIRONMENT_PER_BRANCH=true` set first. The store handle the implementer and the smoke test
use is the `SHOPIFY_STORE_NAME` repository variable, one per repo, so a Palmers country branch cannot
have its own.

**Before each cutover:**
- The repo carries the shared kit. R-Finds does not yet.
- The kit's platform stub pins a release whose reusable matches it. The main-only Vercel stub needs
  the release that carries the main-only reusable.
- A Shopify repo with no build script passes `shopify theme check --fail-level error`, which its build
  job runs on every PR and push. Driver-Horizon fails it (`sections/header.liquid`, Driver-Horizon #10).
- No wave is running. The wave reads `default_branch` live, so one that runs mid-cutover commits to
  whichever branch is the default at that moment.
- No merges into the repo from step 2 to step 6, and those steps run back to back. In between, the old
  deploy workflows push to a theme that has been renamed or fire on the new `main`.

**Steps:**

1. **Read the repo's state before changing anything.**
   - Open PRs by base branch. Merge or close a PR from the working branch into `main`
     (Driver-Digital-Website #170): the rename closes a PR whose head is the renamed branch.
   - The commits only on `main`: `compare/<default>...main`. They are usually old "Update main with
     stable develop" promotions; read them anyway.
   - Open issues whose first line names the old branch. Delete that line.
   - Protection on both branches and environments.
2. **Prepare the platform.**
   - Shopify: in the admin, confirm the exact name of the preview theme (`DRIVER/develop`,
     `Kissy-2.0/develop` or `DRIVER/staging`), that no `DRIVER/main` exists, that the store is under
     its theme limit, and that none of these is the live theme. Then rename the preview theme to
     `DRIVER/main`. The reusable creates a new theme when no theme carries the name, so a mismatch
     fails silently.
   - Vercel: turn off "Auto-assign Custom Production Domains" on the project. On Team-Laird, delete
     the custom `staging` environment.
3. **Tag the old `main` and delete it.**
   - Tag it as `archive/main-<yyyy-mm>` through the API.
   - Retarget any PR whose base is `main` first, because GitHub closes PRs whose base branch is deleted.
   - Delete its protection (`DELETE repos/DriverDigital/<repo>/branches/main/protection`). Every
     cutover repo has `allow_deletions` off there, and the old rule would otherwise linger.
4. **Rename the working branch to `main`:** `POST repos/DriverDigital/<repo>/branches/<develop|staging>/rename`
   with `new_name=main`. GitHub retargets its open PRs, moves its protection rule and makes it the
   default. It does not touch workflow branch filters, Vercel or Dependabot settings, or rulesets
   (fix studio-sulzer's ruleset by hand). Remove any `target-branch: develop` the wave has not.
5. **Vercel only: swap the hooks.** In Vercel, delete the `develop` hook and create a `main` hook
   where there is none (studio-sulzer). On the repo, set `VERCEL_DEPLOY_HOOK_MAIN`, delete
   `VERCEL_DEPLOY_HOOK_DEVELOP`, and set `VERCEL_TEAM_LOGINS` to the logins the old `deploy.yml`
   skips: `mcarter-astronautdev jadewang425` on Driver-Digital-Website; the others can stay on the
   fallback. A login left out deploys twice.
6. **Push one direct commit to `main`.** Leave `skip-ci` out, so the push deploys and proves the
   stub. The commit:
   - deletes the old deploy workflows: every theme workflow in the table above, or the Vercel
     `deploy.yml`
   - adds the platform stub
   - adds `.claude/settings.json` where the wave has not (repos without `claude.yml`)
   - adds the `@.github/claude-standards.md` import to `CLAUDE.md` where it's missing; a repo with
     no `CLAUDE.md` (Kissy-Kissy, LittleMe, R-Finds) has its own to-do
7. **Check that it worked, and set protection.**
   - Shopify: the push run updated `DRIVER/<branch>` (`DRIVER/main` outside Palmers), and a ready PR
     deploys its preview.
   - Vercel: the push staged a build and the production domain still serves the previous
     deployment. A push by a login in `VERCEL_TEAM_LOGINS` skips the hook, so fire
     `VERCEL_DEPLOY_HOOK_MAIN` once by hand and confirm Vercel stages that build too. Promote once,
     then confirm auto-assign is still off.
   - The open PRs target `main`.
   - `main` requires one review. The rename carries `develop`'s or `staging`'s rule over; set it
     where none came across (Team-Laird, whose `develop` is unprotected, and every repo already on
     `main` that lacks it, Palmers' `main*` branches included).
   - `main` requires at least one check and up-to-date branches ([The standards](#the-standards)).
     The rename carries `develop`'s protection over, so a branch that lacked strict still lacks it.
     On Palmers, set it on every `main*` branch.
   - `tools/fleet-pin-audit.sh` shows the repo's row.
   - Close the repo's cutover to-do.
8. **Every clone,** each engineer's included. Check a local `main` for unpushed work first, since
   `-M` replaces it:
   `git fetch --prune origin && git branch -M <develop|staging> main && git branch -u origin/main main && git remote set-head origin -a`

**foundrae-blackridge also needs,** all before step 6 and the integration disconnect before step 3:
- Its store secrets exist both at repo level and in the `staging` and `dev-staging` environments.
  Confirm the repo-level values point at the same store as `staging`'s, then leave
  `SHOPIFY_ENVIRONMENT_PER_BRANCH` unset. If they don't match, create a `main` environment holding
  `staging`'s secrets and set the variable.
- Decide whether `dev-staging` and the `testparty/*` branches stay or go. Tag any you delete;
  `dev-staging` holds commits that were never merged.
- `main` is connected to the unpublished `foundrae/main` theme through Shopify's GitHub integration.
  Disconnect it in the Shopify admin before step 3 deletes `main`.

driver-agents also deploys through Vercel, from `main` only. It is a tool, not a site, so it stays
outside this standard until it needs one.

## Order

1. Release the next tag and wave it (README, *Release + repin order*). It carries the main-only Vercel
   reusable and writes `dependabot.yml`, which drops the Vercel repos' `target-branch: develop`.
2. Canary the `shopify-theme.yml` stub on savannahfriedkin (steps 1, 6 and 7) and read its push job
   log. Then pilot the Shopify cutover on LittleMe: `main` is a strict ancestor of `develop`, it has
   few open PRs and two deploy files, and there is no production workflow. Then the rest, one at a
   time.
3. The Vercel cutovers, one at a time.
4. `tools/fleet-pin-audit.sh --stale` reads converged.
