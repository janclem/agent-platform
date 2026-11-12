import { isAbsolute } from "node:path";
import { CliError, EXIT_CODES, errorDocument } from "./errors.js";

// Agents' credentials: a Doppler config holding only references to the Access
// service-token pair, the API URL and the allowed origins (ADR 23). Locally it
// resolves through the operator's Doppler login; elsewhere a read-only service
// token in DOPPLER_TOKEN selects it.
export const DOPPLER_PROJECT = "work-graph";
export const DOPPLER_CONFIG = "prd_work_graph_agents";
export const DOPPLER_SECRETS = [
  "CF_ACCESS_CLIENT_ID",
  "CF_ACCESS_CLIENT_SECRET",
  "WORK_GRAPH_API_URL",
  "WORK_GRAPH_CF_ACCESS_ALLOWED_ORIGINS",
] as const;

export const DOPPLER_BOOTSTRAP_MARKER = "WORK_GRAPH_DOPPLER_BOOTSTRAPPED";
export const DOPPLER_EXECUTABLE_ENV = "WORK_GRAPH_DOPPLER_BIN";

// Fixed install locations only, never PATH: Homebrew, system packages and
// NixOS. WORK_GRAPH_DOPPLER_BIN names any other absolute path.
const DOPPLER_EXECUTABLE_CANDIDATES = [
  "/opt/homebrew/bin/doppler",
  "/usr/local/bin/doppler",
  "/usr/bin/doppler",
  "/run/current-system/sw/bin/doppler",
] as const;

export const resolveDopplerExecutable = (
  environment: NodeJS.ProcessEnv,
  exists: (path: string) => boolean,
): string | undefined => {
  const configuredPath = environment[DOPPLER_EXECUTABLE_ENV];
  if (configuredPath !== undefined) {
    return isAbsolute(configuredPath) && exists(configuredPath)
      ? configuredPath
      : undefined;
  }

  return DOPPLER_EXECUTABLE_CANDIDATES.find(exists);
};

export const dopplerSpawnExitCode = (
  child: { error?: Error; status: number | null },
  stderr: (text: string) => void,
): number => {
  if (child.error === undefined) return child.status ?? EXIT_CODES.transport;

  const error = new CliError(
    "DOPPLER_SPAWN_FAILED",
    `Failed to start Doppler: ${child.error.message}`,
    EXIT_CODES.transport,
    { cause: child.error },
  );
  stderr(`${JSON.stringify(errorDocument(error))}\n`);
  return error.exitCode;
};

const optionConsumesValue = new Set([
  "--api-url",
  "--cf-access-allowed-origin",
]);

const rootCommand = (args: readonly string[]): string | undefined => {
  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument === undefined) return undefined;
    if (optionConsumesValue.has(argument)) {
      index += 1;
      continue;
    }
    if (argument.startsWith("--api-url=") || argument.startsWith("--cf-access-allowed-origin=")) {
      continue;
    }
    if (argument.startsWith("-")) return undefined;
    return argument;
  }
  return undefined;
};

const doesNotNeedApi = (args: readonly string[]): boolean =>
  args.length === 0 ||
  args.includes("--help") ||
  args.includes("-h") ||
  args.includes("--version") ||
  args.includes("-V") ||
  ["help", "prime", "self-update"].includes(rootCommand(args) ?? "");

const hasApiUrlOption = (args: readonly string[]): boolean =>
  args.some((arg) => arg === "--api-url" || arg.startsWith("--api-url="));

export const dopplerBootstrapArgs = (
  args: readonly string[],
  environment: NodeJS.ProcessEnv,
  nodeExecutable: string,
  cliScript: string,
): string[] | undefined => {
  if (
    environment.WORK_GRAPH_API_URL ||
    environment[DOPPLER_BOOTSTRAP_MARKER] === "1" ||
    hasApiUrlOption(args) ||
    doesNotNeedApi(args)
  ) {
    return undefined;
  }

  return [
    "run",
    "--project",
    DOPPLER_PROJECT,
    "--config",
    DOPPLER_CONFIG,
    "--only-secrets",
    DOPPLER_SECRETS.join(","),
    "--",
    nodeExecutable,
    cliScript,
    ...args,
  ];
};
