import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { afterEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  closeDb: vi.fn(),
  createDb: vi.fn(() => ({})),
  evaluate: vi.fn(),
  listGitHubReconciliationTargets: vi.fn(),
  listExpiredLeaseCompletionTargets: vi.fn(),
}));
vi.mock("work-graph-db", () => ({
  closeDb: mocks.closeDb,
  createDb: mocks.createDb,
  GitHubDeliveryConsumer: class {},
  WorkGraphRepository: class {
    evaluateCompletionCandidateAndReleaseIfConfigured = mocks.evaluate;
    listExpiredLeaseCompletionTargets = mocks.listExpiredLeaseCompletionTargets;
    listGitHubReconciliationTargets = mocks.listGitHubReconciliationTargets;
  },
}));

import worker, {
  LEASE_EXPIRY_SWEEP_CRON,
  leaseExpiryEvaluationId,
  type ObserverBindings,
  runLeaseExpirySweep,
} from "../src/index";

const env = {
  HYPERDRIVE: { connectionString: "postgres://test" },
} as ObserverBindings;
const target = (workItemId: string, leaseId: string) => ({
  workItemId,
  leaseId,
  leaseExpiresAt: "2026-11-13T18:47:20.000Z",
});

describe("lease-expiry sweep", () => {
  afterEach(() => vi.resetAllMocks());

  it("evaluates each bounded target once and closes the database", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    const targets = [
      target("released", "00000000-0000-4000-8000-000000000001"),
      target("manual", "00000000-0000-4000-8000-000000000002"),
      target("failing", "00000000-0000-4000-8000-000000000003"),
      target("unconfigured", "00000000-0000-4000-8000-000000000004"),
    ];
    mocks.listExpiredLeaseCompletionTargets.mockResolvedValueOnce(targets);
    mocks.evaluate
      .mockResolvedValueOnce({ automaticReleaseOutcome: "released" })
      .mockResolvedValueOnce({
        automaticReleaseOutcome: "automatic_release_disabled",
      })
      .mockRejectedValueOnce(new Error("secret database error"))
      .mockResolvedValueOnce(null);

    await expect(runLeaseExpirySweep(env)).resolves.toEqual({
      targets: 4,
      outcomes: {
        released: 1,
        automatic_release_disabled: 1,
        failed: 1,
        unconfigured: 1,
      },
    });
    expect(mocks.listExpiredLeaseCompletionTargets).toHaveBeenCalledWith(10);
    for (const [index, item] of targets.entries()) {
      expect(mocks.evaluate).toHaveBeenNthCalledWith(index + 1, {
        id: await leaseExpiryEvaluationId(item),
        workItemId: item.workItemId,
        evaluatedAt: item.leaseExpiresAt,
      });
    }
    expect(mocks.closeDb).toHaveBeenCalledOnce();
    expect(JSON.stringify(log.mock.calls)).not.toContain("secret");
    log.mockRestore();
  });

  it("derives a stable UUID per expired lease", async () => {
    const first = target("item", "00000000-0000-4000-8000-000000000001");
    const id = await leaseExpiryEvaluationId(first);
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
    );
    await expect(leaseExpiryEvaluationId({ ...first })).resolves.toBe(id);
    await expect(
      leaseExpiryEvaluationId({
        ...first,
        leaseId: "00000000-0000-4000-8000-000000000002",
      }),
    ).resolves.not.toBe(id);
  });

  it("runs the sweep, not reconciliation, on its own cron", async () => {
    const log = vi.spyOn(console, "log").mockImplementation(() => {});
    mocks.listExpiredLeaseCompletionTargets.mockResolvedValueOnce([]);
    await worker.scheduled(
      { cron: LEASE_EXPIRY_SWEEP_CRON } as ScheduledController,
      env,
    );
    expect(mocks.listExpiredLeaseCompletionTargets).toHaveBeenCalledOnce();
    expect(mocks.listGitHubReconciliationTargets).not.toHaveBeenCalled();
    expect(log).toHaveBeenCalledWith(
      JSON.stringify({
        operation: "lease-expiry-sweep",
        targets: 0,
        outcomes: {},
      }),
    );
    log.mockRestore();
  });

  it("is scheduled in wrangler.toml", async () => {
    const config = await readFile(
      resolve(__dirname, "../wrangler.toml"),
      "utf8",
    );
    expect(config).toContain(`"${LEASE_EXPIRY_SWEEP_CRON}"`);
  });
});
