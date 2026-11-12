import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import {
  normalizeGeneratedDeliveryMetadata,
  resolveDeliveryTargets,
} from "work-graph-domain";
import {
  DELIVERY_TARGETS_PATH,
  deliveryMetadataFromPlatform,
} from "../src/reconciliation";

const repository = "janclem/agent-platform";

const metadata = async () =>
  normalizeGeneratedDeliveryMetadata(
    deliveryMetadataFromPlatform(
      await readFile(resolve(__dirname, "../../..", DELIVERY_TARGETS_PATH), "utf8"),
      repository,
      "test-revision",
    ),
  );

const targetIds = async (ticketProjectId: string, changedPaths: string[]) =>
  resolveDeliveryTargets({
    metadata: await metadata(),
    repository,
    ticketProjectId,
    changedPaths,
  }).targets.map(({ id }) => id);

describe("this repository's delivery targets", () => {
  it("parse and normalize", async () => {
    expect((await metadata()).targets.length).toBeGreaterThan(0);
  });

  it("require CI and a production deployment for the API", async () => {
    const resolution = resolveDeliveryTargets({
      metadata: await metadata(),
      repository,
      ticketProjectId: "work-graph",
      changedPaths: ["services/work-graph-api/src/app.ts", "pnpm-lock.yaml"],
    });
    expect(resolution.targets).toEqual([
      expect.objectContaining({
        id: "delivery-target:work-graph/service",
        requiredCiNames: ["CI"],
        productionEnvironments: ["production-work-graph"],
      }),
    ]);
  });



  it("send CLI changes through the deployed service target", async () => {
    expect(
      await targetIds("work-graph", ["packages/work-graph-cli/src/main.ts"]),
    ).toEqual(["delivery-target:work-graph/service"]);
  });
});
