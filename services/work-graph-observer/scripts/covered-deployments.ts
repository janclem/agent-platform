// Chooses which earlier main commits a deployment also delivered. Completion
// evaluation wants a production deployment at each pull request's exact merge
// commit, but a deploy or apply ships everything up to the commit it ran at:
// superseded queued runs and changes applied together never get their own
// deployment. A commit counts as covered when it lies on main's first-parent
// history after the previous successful deployment to the environment, maps to
// a delivery target that lists the environment, and has no successful
// deployment there yet. Resolution uses the same catalog parser and resolver as
// completion evaluation, across every project.
import {
  normalizeGeneratedDeliveryMetadata,
  resolveDeliveryTargets,
} from "work-graph-domain";
import { deliveryMetadataFromPlatform } from "../src/reconciliation";

export interface MainCommit {
  readonly sha: string;
  readonly changedPaths: readonly string[];
}

export interface CoveredDeploymentsInput {
  readonly repository: string;
  readonly environment: string;
  readonly catalog: string;
  readonly catalogRevision: string;
  // First-parent commits after the previous successful deployment, oldest
  // first, excluding the commit that was just deployed.
  readonly commits: readonly MainCommit[];
  readonly alreadyDeployed: ReadonlySet<string>;
}

export interface CoveredCommit {
  readonly sha: string;
  readonly targetIds: readonly string[];
}

export const coveredCommits = (input: CoveredDeploymentsInput): CoveredCommit[] => {
  const metadata = normalizeGeneratedDeliveryMetadata(
    deliveryMetadataFromPlatform(input.catalog, input.repository, input.catalogRevision),
  );
  return input.commits.flatMap((commit) => {
    if (input.alreadyDeployed.has(commit.sha) || commit.changedPaths.length === 0) return [];
    const targetIds = resolveDeliveryTargets({
      metadata,
      repository: input.repository,
      ticketProjectId: null,
      changedPaths: [...commit.changedPaths],
    })
      .targets.filter(({ productionEnvironments }) =>
        productionEnvironments.includes(input.environment),
      )
      .map(({ id }) => id);
    return targetIds.length > 0 ? [{ sha: commit.sha, targetIds }] : [];
  });
};
