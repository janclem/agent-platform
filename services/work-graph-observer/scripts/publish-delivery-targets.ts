// Publishes this repository's .work-graph/delivery-targets.yaml to the Work
// Graph API at the checked-out commit, using the reconciler's own parser. The
// revision is the file's git blob SHA, the same ID the six-hourly reconciliation
// reads from GitHub, so publishing twice or racing reconciliation is harmless.
// Credentials come from the environment (see publish-delivery-targets.sh).
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  DELIVERY_TARGETS_PATH,
  deliveryMetadataFromPlatform,
} from "../src/reconciliation";

const required = (name: string): string => {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is required.`);
  return value;
};

const git = (...args: string[]): string =>
  execFileSync("git", args, { encoding: "utf8" }).trim();

const root = git("rev-parse", "--show-toplevel");
const repository = (
  process.env.GITHUB_REPOSITORY ?? "janclem/agent-platform"
).toLowerCase();
const sourceRevision = git("rev-parse", `HEAD:${DELIVERY_TARGETS_PATH}`);
const createdAt = new Date(git("show", "-s", "--format=%cI", "HEAD")).toISOString();
const metadata = deliveryMetadataFromPlatform(
  readFileSync(join(root, DELIVERY_TARGETS_PATH), "utf8"),
  repository,
  sourceRevision,
);

const apiUrl = new URL(required("WORK_GRAPH_API_URL"));
const allowedOrigins = required("WORK_GRAPH_CF_ACCESS_ALLOWED_ORIGINS")
  .split(",")
  .map((origin) => origin.trim());
if (!allowedOrigins.includes(apiUrl.origin)) {
  throw new Error("WORK_GRAPH_API_URL is not an allowed Access origin.");
}

const [owner, name] = repository.split("/");
const url = new URL(
  `/api/github/repositories/${encodeURIComponent(owner ?? "")}/${encodeURIComponent(
    name ?? "",
  )}/delivery-metadata-revisions/${sourceRevision}`,
  apiUrl,
);
const response = await fetch(url, {
  method: "PUT",
  redirect: "manual",
  headers: {
    "Content-Type": "application/json",
    "CF-Access-Client-Id": required("CF_ACCESS_CLIENT_ID"),
    "CF-Access-Client-Secret": required("CF_ACCESS_CLIENT_SECRET"),
  },
  body: JSON.stringify({ targets: metadata.targets, createdAt }),
});
if (!response.ok) {
  throw new Error(
    `Publishing delivery targets failed with HTTP ${response.status}: ${(await response.text()).slice(0, 500)}`,
  );
}
console.log(
  `Published ${metadata.targets.length} delivery targets for ${repository} at revision ${sourceRevision}: ${metadata.targets
    .map((target) => target.id)
    .join(", ")}`,
);
