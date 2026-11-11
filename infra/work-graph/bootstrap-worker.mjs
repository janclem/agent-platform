// Adapted from Robbie-Palmer/hq (infra/work-graph), AGPL-3.0.
// Fail-closed placeholder until Wrangler deploys the application.
export default {
  fetch() {
    return new Response("Work Graph deployment pending", { status: 503 });
  },
};
