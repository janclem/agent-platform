// Adapted from Robbie-Palmer/hq (workers/work-graph-api/src/authorization.ts), AGPL-3.0.
//
// Every authenticated client has full access (ADR 17). The authorizer keeps
// hq's request shape so a Cedar policy set can replace it when the first client
// that must not mutate appears, without changing the app's middleware.
import { z } from "zod";

export const WorkGraphAuthorityProfileSchema = z.enum([
  "authority:work-graph-full",
]);
export type WorkGraphAuthorityProfile = z.infer<
  typeof WorkGraphAuthorityProfileSchema
>;

export const WorkGraphAuthorizationActionSchema = z.enum([
  "api.read",
  "api.write",
]);
export type WorkGraphAuthorizationAction = z.infer<
  typeof WorkGraphAuthorizationActionSchema
>;

const WorkGraphAuthorizationRequestSchema = z
  .object({
    action: WorkGraphAuthorizationActionSchema,
    authorityProfileId: WorkGraphAuthorityProfileSchema,
    method: z.string().trim().min(1).max(16),
    path: z.string().trim().min(1).max(2_048),
    principalId: z.string().trim().min(1).max(200),
  })
  .strict();
export type WorkGraphAuthorizationRequest = z.infer<
  typeof WorkGraphAuthorizationRequestSchema
>;

export type WorkGraphAuthorizationDecision =
  | { readonly decision: "allow" }
  | {
      readonly decision: "deny";
      readonly reason: "invalid-request";
      readonly diagnostics: readonly string[];
    };

export interface WorkGraphAuthorizer {
  authorize(
    request: WorkGraphAuthorizationRequest,
  ): WorkGraphAuthorizationDecision;
}

export const workGraphAuthorizer: WorkGraphAuthorizer = {
  authorize(requestInput) {
    const parsedRequest =
      WorkGraphAuthorizationRequestSchema.safeParse(requestInput);
    if (!parsedRequest.success) {
      return {
        decision: "deny",
        reason: "invalid-request",
        diagnostics: parsedRequest.error.issues.map(
          (issue) => `${issue.path.join(".")}: ${issue.message}`,
        ),
      };
    }
    return { decision: "allow" };
  },
};

export const workGraphActionForRequest = (
  method: string,
): WorkGraphAuthorizationAction =>
  ["GET", "HEAD", "OPTIONS", "QUERY"].includes(method.toUpperCase())
    ? "api.read"
    : "api.write";
