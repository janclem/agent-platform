# New project repository

Project repositories are created by Terraform in `infra/foundation` and filled from the
Copier template. Each one gets the platform's merge policy from
`infra/foundation/modules/project-repo`: squash-only pull requests to a protected `main`,
gated by `platform / checks`.

## 1. Create the repository

1. Add the project to `local.repositories` in `infra/foundation/github.tf`:

   ```hcl
   my-project = {
     description = "One-line description"
     # visibility = "private"  # default public; secret scanning is public-only
   }
   ```

2. Open a PR with the `terraform plan` summary. Expect only additions for the new
   repository, its ruleset, and its security settings.
3. After merge, the owner applies the run in HCP. The workspace's `GITHUB_TOKEN` must be
   allowed to create repositories (a fine-grained token needs access to all repositories
   with Administration write).

The repository starts with one commit on `main`, so everything after it arrives by
pull request through the same gates.

## 2. Fill it from the template

```bash
gh repo clone janclem/<project> && cd <project>
git switch -c init
copier copy --trust --overwrite gh:janclem/agent-platform .
git add -A && git commit -m "Initialize from agent-platform template"
git push -u origin init
gh pr create --fill
```

Merge once `platform / checks` passes. The `.copier-answers.yml` file records the
template release; `copier update` pulls later releases.

## 3. Finish the delivery contract

Fill in **Scope** in `docs/runbooks/delivery-contract.md` before an agent deploys
anything from the new repository.

## 4. Connect it to the Work Graph

Agents in the new repository use the `work-graph` skill, which the template ships. To
let the GitHub observer record the project's PRs, CI runs and deployments as delivery
evidence (ADR 19):

1. Add the repository to the `janclem-work-graph-observer` App's installation
   (GitHub → Settings → Applications → the App → Configure → Repository access).
2. Add `janclem/<project>` to the JSON array in `GITHUB_ALLOWED_REPOSITORIES` in Doppler
   `work-graph/prd_work_graph`, then redeploy the observer with
   `mise run work-graph:observer-deploy` (or rerun Work Graph CD).
3. Create the project's scope with `work-graph scope put <project> --kind project ...`.
4. Once the project deploys through a GitHub environment, add
   `.work-graph/delivery-targets.yaml` to it, naming the CI workflow and production
   environment that prove delivery. See
   [the observer README](../../services/work-graph-observer/README.md#correlation-and-delivery-targets).
