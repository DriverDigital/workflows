# Branch model and the two platform standards

Driver sites are hosted on Shopify, Vercel or WordPress. Shopify and Vercel each have their own CI/CD
standard; WordPress has none yet, so its repos take the shared kit only. The shared kit (implementer,
Dependabot rails, lint, Bonsai link, PR template, house standards, `.claude/settings.json`) is waved
to enrolled repos, and `dependabot.yml` is written by hand in each one. A platform's files go only
to repos of that platform. The fleet survey behind this was taken 2026-10-08.

## Which repos get what

Four GitHub topics on each repo decide it. Which files each platform adds is listed in `tools/kit-platforms.sh`.

| Topic | Means |
|---|---|
| `driver-kit` | The repo takes the kit. `tools/fleet-wave.sh` targets nothing without it, so a stale repo receives nothing further without being archived. |
| `shopify-theme` | A Shopify site: adds the Shopify files. |
| `vercel-site` | A Vercel site: adds the Vercel files. |
| `wordpress-site` | A WordPress site: no platform files yet, so the shared kit only. |

A repo carries at most one platform topic; the wave stops on a repo with two.

The platform topics describe the repo, and `driver-kit` opts it in, so a dormant theme can carry
`shopify-theme` and still receive nothing. The audit scans every repo regardless. Kit workflow files
on a repo without `driver-kit` are listed in their own `unenrolled` section, which never fails the
audit, so a dormant repo can keep its old files until it is archived. A platform file on a repo of
another platform or of none is drift, and the wave refuses to write one there.

Set 2026-10-09:

| Topics | Repos |
|---|---|
| `driver-kit` + `shopify-theme` | Avara, foundrae-blackridge, LaPointe, Kissy-Kissy, LittleMe, Palmers, R-Finds, savannahfriedkin, Driver-Horizon, Anduril-Gear |
| `driver-kit` + `vercel-site` | Team-Laird, Driver-Digital-Website, studio-sulzer |
| `driver-kit` + `wordpress-site` | The-Gathery |
| `driver-kit` only | vite-plugin-shopify-clean, plugins, client-workspaces, driver-onboarding, driver-engineering-app, driver-agents |

driver-agents is enrolled but is not a wave target until it carries a file the wave discovers by.
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

An enrolled repo with no platform topic gets the shared kit only, the way the tool repos
(`plugins`, `client-workspaces`, `vite-plugin-shopify-clean`, `driver-onboarding`,
`driver-engineering-app`, `driver-agents`) do. The-Gathery is a WordPress theme with `develop` +
`main`; `wordpress-site` adds no files yet, so it too gets the shared kit only.

No repo branch is ever connected to a store's live theme. Repos back unpublished preview themes
only, so a branch rename never touches a live storefront.

## Where branch names are hard-coded today

This repo names branches only where a standard does, by design. The two platform stubs filter on their
standard's branches (`main`/`main-*`; `main`/`develop`), `vercel-deploy.yml` tells production from
preview by `refs/heads/main` and `refs/heads/develop`, and `templates/github/lint.yml` runs on `push: [main]`.
Nothing else does: the implementer takes its base from the dispatcher's `Target branch:` line or the
repo default, the Dependabot reusables follow the PR, and the wave and the audit follow each repo's
default branch, plus every Palmers branch named `main*`.

Elsewhere:

| Where | What names a branch |
|---|---|
| driver-agents `pipeline/project-repo-map.json` | 11 entries: 9 `develop` (studio-sulzer, Avara ×4, Driver-Digital-Website, LaPointe, LittleMe, Kissy-Kissy), 2 `staging` (foundrae). The dispatcher writes the entry's branch on line 1 of every issue, and the implementer bases its branch and PR on it. Open issues filed before a cutover still carry the old name. |
| Theme deploy workflows | Avara, LaPointe, Kissy-Kissy, LittleMe, R-Finds: `Feature-*` on PRs to `develop`, `Develop-Deploy` on push to `develop` → `DRIVER/develop` (Kissy-Kissy: `Kissy-2.0/develop`), and `Production-Deploy` on push to `main` (Avara, LaPointe, R-Finds; never run). foundrae: `Feature-*` and `Staging-Deploy` on `staging`/`dev-staging` → `DRIVER/<branch>`. |
| Vercel `deploy.yml` | Team-Laird, Driver-Digital-Website: `refs/heads/main` → production hook, `refs/heads/develop` → preview hook, skipped for the Vercel team's logins (`mcarter-astronautdev`; Driver-Digital-Website also `jadewang425`). studio-sulzer has none. |
| Vercel project settings | Production branch and Team-Laird's custom `staging` environment, which follows `develop`. Set in Vercel, not in git. |
| `dependabot.yml` `target-branch: develop` | Team-Laird ×2, Driver-Digital-Website, studio-sulzer: redundant, since `develop` is the default. sandbox-vite-plugin-shopify-clean ×2 points at a branch that doesn't exist. |
| GitHub environments | foundrae: `staging`, `dev-staging`, `testparty/06-2026` hold the store secrets, picked by branch name. Palmers: one per branch. None of them has a deployment branch policy. |
| Protection | `develop` requires 1 review in Avara, LaPointe, Kissy-Kissy, LittleMe, R-Finds, The-Gathery, studio-sulzer, Driver-Digital-Website. `main` requires 0 in Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds, and 1 in foundrae; every cutover repo's `main` has `allow_deletions` off. studio-sulzer's ruleset "Restrict main and develop" names both branches (disabled). |

## Shopify cutover, one repo at a time

**Repos to cut over:** Avara, LaPointe, Kissy-Kissy, LittleMe and R-Finds (from `develop`), and
foundrae-blackridge (from `staging`).

**Already on `main`:** Palmers, savannahfriedkin, Driver-Horizon and Anduril-Gear. They take steps 1,
5 and 6 only: step 5's commit deletes their `Feature-*` and `Staging-Deploy` files, and on Palmers it
lands on every `main*` branch, with `SHOPIFY_ENVIRONMENT_PER_BRANCH=true` set first.

**Before the first cutover:**
- The release carrying `shopify-theme.yml` is tagged, and its stub is repinned into the kit (README
  release order, step 2).
- driver-agents' map names `main` for the repo.
- The repo carries the `driver-kit` and `shopify-theme` topics.
- A repo with no build script passes `shopify theme check --fail-level error`, which its build job
  runs on every PR and push. Driver-Horizon fails it today (`sections/header.liquid`).
- No wave is running. The wave reads `default_branch` live, so one that runs mid-cutover commits to
  whichever branch is the default at that moment.

**Steps:**

1. **Read the repo's state before changing anything.**
   - Open PRs by base branch.
   - The commits only on `main`: `compare/<default>...main`. In every repo surveyed they are old
     "Update main with stable develop" promotions, but read them.
   - Open issues whose first line names the old branch.
   - Protection on both branches, environments, and `dependabot.yml`'s `target-branch`.
2. **Rename the preview theme in the Shopify admin** from `DRIVER/develop` (or `Kissy-2.0/develop`,
   `DRIVER/staging`) to `DRIVER/main`. The first push then updates it in place instead of creating
   a new theme.
3. **Tag the old `main` and delete it.**
   - Tag it as `archive/main-2026-10` through the API.
   - Delete its protection (`DELETE repos/DriverDigital/<repo>/branches/main/protection`). Every
     cutover repo has `allow_deletions` off there, and the old rule would otherwise linger.
   - Retarget any PR whose base is `main` before the delete, because GitHub closes PRs whose base
     branch is deleted.
4. **Rename the working branch to `main`:** `POST repos/DriverDigital/<repo>/branches/<develop|staging>/rename`
   with `new_name=main`. GitHub retargets its open PRs, moves its protection rule and makes it the
   default. It does not touch workflow branch filters, Vercel or Dependabot settings, or rulesets
   (fix studio-sulzer-style rulesets by hand).
5. **Push one direct commit to `main`.** Leave `skip-ci` out, so the push deploys `DRIVER/main` and
   proves the stub. The commit:
   - deletes the old theme workflows (`Feature-*`, `Develop-Deploy`, `Staging-Deploy`, `Production-Deploy`,
     any lowercase variants)
   - adds the `shopify-theme.yml` stub
   - writes `dependabot.yml` from the kit (keeping the blocks the repo needs)
   - adds `.claude/settings.json` where the wave has not (repos without `claude.yml`)
   - adds the `@.github/claude-standards.md` import to `CLAUDE.md` where it's missing (#83)
6. **Check that it worked.**
   - The push run created or updated `DRIVER/main`.
   - The open PRs now target `main`, and a ready PR deploys its preview.
   - `main` carries the 1-review rule that came over from `develop`/`staging`.
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
- Decide whether `dev-staging` is retired. It has been stale since 2026-04.
- `main` is connected to the unpublished `foundrae/main` theme through Shopify's GitHub integration.
  Folding `staging` in syncs 484 commits to it, so look at that theme first.

## Vercel install, per site

No branch changes:

1. Confirm the repo carries `driver-kit` and `vercel-site` (set 2026-10-09).
2. Confirm both hook secrets exist. studio-sulzer has no `deploy.yml` today, so create its two hooks
   in Vercel first.
3. Set `VERCEL_TEAM_LOGINS` on the repo to the logins its current `deploy.yml` skips. That's
   `mcarter-astronautdev jadewang425` on Driver-Digital-Website; Team-Laird can stay on the
   fallback. A login left out deploys twice.
4. Push one direct commit to `develop`:
   - add the `vercel-deploy.yml` stub
   - delete `deploy.yml`
   - write `dependabot.yml` from the kit (its `target-branch: develop` goes)
   - add `.claude/settings.json` where the wave has not (repos without `claude.yml`)
   - add the `@.github/claude-standards.md` import to `CLAUDE.md` where it's missing (#83)

   `main` picks the commit up at the next promotion. Until then, `main`'s own `deploy.yml` keeps
   working.

driver-agents also deploys through Vercel, from `main` only. It is a tool, not a site, so it stays
outside this standard until it needs one.

## Order

1. Merge, tag, and repin with the two new stubs added (README release order).
2. The topics are set (2026-10-09, [Which repos get what](#which-repos-get-what)).
3. Wave the shared kit. That carries `.claude/settings.json` and the updated house standards to
   every implementer repo.
4. Canary the `shopify-theme.yml` stub on savannahfriedkin, already on `main` (steps 1, 5 and 6),
   and read its push job log (HANDOFF watch-items). Then pilot the Shopify cutover on LittleMe: `main`
   is a strict ancestor of `develop`, it has one open PR and two deploy files, and there is no
   production workflow. Then the rest, one at a time.
5. Vercel installs.
6. `tools/fleet-pin-audit.sh --stale` reads converged.
