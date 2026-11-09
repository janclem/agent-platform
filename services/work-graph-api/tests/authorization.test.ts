// Adapted from Robbie-Palmer/hq (workers/work-graph-api/tests/authorization.test.ts), AGPL-3.0.
import {
  createWorkGraphApp,
  type WorkGraphApiRepository,
} from "../src/app";
import {
  workGraphActionForRequest,
  workGraphAuthorizer,
} from "../src/authorization";

describe("Work Graph client authorization", () => {
  it("allows the full authority profile to read and write", () => {
    for (const [action, method] of [
      ["api.read", "GET"],
      ["api.write", "POST"],
    ] as const) {
      expect(
        workGraphAuthorizer.authorize({
          action,
          authorityProfileId: "authority:work-graph-full",
          method,
          path: "/api/work-items",
          principalId: "client:operator",
        }),
      ).toEqual({ decision: "allow" });
    }
  });

  it("fails closed when the authorization request is malformed", () => {
    expect(
      workGraphAuthorizer.authorize({
        action: "api.read",
        authorityProfileId: "authority:work-graph-full",
        method: "",
        path: "/api/work-items",
        principalId: "client:operator",
      }),
    ).toMatchObject({ decision: "deny", reason: "invalid-request" });
  });

  it("maps HTTP methods to read and write actions", () => {
    expect(workGraphActionForRequest("GET")).toBe("api.read");
    expect(workGraphActionForRequest("HEAD")).toBe("api.read");
    expect(workGraphActionForRequest("QUERY")).toBe("api.read");
    expect(workGraphActionForRequest("POST")).toBe("api.write");
  });

  it("enforces the authorizer's decision before a route handler runs", async () => {
    const app = createWorkGraphApp({} as WorkGraphApiRepository, {
      authorization: {
        authorizer: {
          authorize: () => ({
            decision: "deny",
            reason: "invalid-request",
            diagnostics: [],
          }),
        },
      },
    });

    const response = await app.request("/api/work-items", { method: "POST" });
    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      error: {
        code: "authorization_denied",
        message: "The authenticated client cannot perform this action.",
      },
    });
  });
});
