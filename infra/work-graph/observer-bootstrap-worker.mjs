// Adapted from Robbie-Palmer/hq (infra/work-graph/observer-bootstrap-worker.mjs), AGPL-3.0.
// Fail-closed placeholder until Wrangler deploys the observer.
export default {
  fetch() {
    return Response.json(
      { error: "Work Graph observer deployment is pending" },
      { status: 503 },
    );
  },
};
