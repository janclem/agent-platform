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

const targetsFor = async (ticketProjectId: string, changedPaths: string[]) =>
  resolveDeliveryTargets({
    metadata: await metadata(),
    repository,
    ticketProjectId,
    changedPaths,
  }).targets.map(({ id, productionEnvironments }) => ({
    id,
    productionEnvironments,
  }));

describe("this repository's delivery targets", () => {
  it("parse and normalize", async () => {
    expect((await metadata()).targets.length).toBeGreaterThan(0);
  });

  it.each([
    [
      "the API",
      "work-graph",
      ["services/work-graph-api/src/app.ts", "pnpm-lock.yaml"],
      [{ id: "delivery-target:work-graph/service", productionEnvironments: ["production-work-graph"] }],
    ],
    [
      "the CLI",
      "work-graph",
      ["packages/work-graph-cli/src/main.ts"],
      [{ id: "delivery-target:work-graph/service", productionEnvironments: ["production-work-graph"] }],
    ],
    [
      "the catalog itself",
      "work-graph",
      [".work-graph/delivery-targets.yaml"],
      [{ id: "delivery-target:work-graph/service", productionEnvironments: ["production-work-graph"] }],
    ],
    [
      "Work Graph Terraform",
      "work-graph",
      ["infra/work-graph/main.tf"],
      [
        {
          id: "delivery-target:work-graph/infrastructure",
          productionEnvironments: ["production-work-graph-infra"],
        },
      ],
    ],
    [
      "backups",
      "work-graph",
      ["backups/scripts/lib.sh"],
      [{ id: "delivery-target:work-graph/backups", productionEnvironments: ["production-agent-platform"] }],
    ],
    [
      "the template",
      "agent-platform",
      ["template/AGENTS.md.jinja", "mise.toml"],
      [
        {
          id: "delivery-target:agent-platform/platform",
          productionEnvironments: ["production-agent-platform"],
        },
      ],
    ],
  ])("map %s to its deployment signal", async (_label, project, paths, expected) => {
    expect(await targetsFor(project, paths)).toEqual(expected);
  });

  it("require every matched target's deployment", async () => {
    expect(
      await targetsFor("work-graph", [
        "infra/work-graph/scripts/record-deployment.sh",
        "services/work-graph-observer/scripts/publish-delivery-targets.ts",
      ]),
    ).toEqual([
      { id: "delivery-target:work-graph/infrastructure", productionEnvironments: ["production-work-graph-infra"] },
      { id: "delivery-target:work-graph/service", productionEnvironments: ["production-work-graph"] },
    ]);
  });

  it("reject paths no target in the ticket's project owns", async () => {
    await expect(targetsFor("work-graph", ["template/AGENTS.md.jinja"])).rejects.toThrow(
      "do not identify a delivery target",
    );
  });
});
