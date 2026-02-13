import type { OpenClawPluginApi } from "openclaw/plugin-sdk";
import { randomUUID } from "node:crypto";
import { writeFile, readFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { existsSync } from "node:fs";

const DEFAULT_REQUEST_DIR = "/home/openclaw/.openclaw/perm-requests";
const DEFAULT_RESPONSE_DIR = "/home/openclaw/.openclaw/perm-responses";

export default function register(api: OpenClawPluginApi) {
  const requestDir = (api.pluginConfig as any)?.requestDir || DEFAULT_REQUEST_DIR;
  const responseDir = (api.pluginConfig as any)?.responseDir || DEFAULT_RESPONSE_DIR;

  api.registerTool(
    (ctx) => {
      if (!ctx.agentId) return null;

      return {
        name: "request_permission",
        description:
          "Request additional permissions from the system broker. Use this when you encounter a permission error and need expanded capabilities (tool access, network, memory, workspace). The request will be evaluated by an automated broker and either approved, temporarily granted, or escalated for human review.",
        parameters: {
          type: "object",
          properties: {
            permission_type: {
              type: "string",
              enum: ["tool_access", "network_access", "workspace_access", "memory_increase"],
              description: "Category of permission being requested",
            },
            details: {
              type: "string",
              description: "Specific permission needed, e.g. 'group:web', 'host', '4g', 'rw'",
            },
            reason: {
              type: "string",
              description: "Clear explanation of why this permission is needed for the current task",
            },
            duration: {
              type: "string",
              enum: ["permanent", "session", "1h", "4h", "24h"],
              description: "How long the permission is needed. Default: session",
            },
          },
          required: ["permission_type", "details", "reason"],
        },
        async execute(params: Record<string, unknown>) {
          const id = randomUUID();
          const agentId = ctx.agentId || "unknown";
          const config = ctx.config as any;

          // Find current agent permissions
          const agentEntry = config?.agents?.list?.find(
            (a: any) => a.id === agentId,
          );
          const currentPerms = {
            tools_allow: agentEntry?.tools?.sandbox?.tools?.allow || [],
            network: agentEntry?.sandbox?.docker?.network || config?.agents?.defaults?.sandbox?.docker?.network || "none",
            workspace_access: agentEntry?.sandbox?.workspaceAccess || config?.agents?.defaults?.sandbox?.workspaceAccess || "none",
            memory: agentEntry?.sandbox?.docker?.memory || config?.agents?.defaults?.sandbox?.docker?.memory || "1g",
          };

          const request = {
            id,
            timestamp: new Date().toISOString(),
            agent_id: agentId,
            agent_name: agentEntry?.name || agentId,
            session_key: ctx.sessionKey || "",
            permission_type: params.permission_type as string,
            details: params.details as string,
            reason: params.reason as string,
            duration: (params.duration as string) || "session",
            current_permissions: currentPerms,
          };

          try {
            await mkdir(requestDir, { recursive: true });
            await writeFile(
              join(requestDir, `${id}.json`),
              JSON.stringify(request, null, 2),
              "utf-8",
            );
          } catch (err) {
            return {
              content: [
                {
                  type: "text",
                  text: `Failed to submit permission request: ${(err as Error).message}. The permissions broker may not be configured.`,
                },
              ],
            };
          }

          // Poll for response (up to 60 seconds)
          const responsePath = join(responseDir, `${id}.json`);
          const maxWait = 60000;
          const pollInterval = 2000;
          let elapsed = 0;

          while (elapsed < maxWait) {
            await new Promise((r) => setTimeout(r, pollInterval));
            elapsed += pollInterval;

            if (existsSync(responsePath)) {
              try {
                const response = JSON.parse(
                  await readFile(responsePath, "utf-8"),
                );
                if (response.decision === "approve") {
                  return {
                    content: [{
                      type: "text",
                      text: `Permission APPROVED: ${response.reason}\n\nChanges applied: ${response.changes_applied.join(", ")}\n\nThe gateway is restarting to apply changes. Please retry your action in a few seconds.`,
                    }],
                  };
                } else if (response.decision === "temporary") {
                  return {
                    content: [{
                      type: "text",
                      text: `Permission TEMPORARILY GRANTED: ${response.reason}\n\nChanges applied: ${response.changes_applied.join(", ")}\nExpires at: ${response.revert_at}\n\nThe gateway is restarting. Please retry your action in a few seconds.`,
                    }],
                  };
                } else if (response.decision === "escalate") {
                  return {
                    content: [{
                      type: "text",
                      text: `Permission ESCALATED for human review: ${response.reason}\n\nYour request has been queued for the system operator. You will need to wait for manual approval or try a different approach.`,
                    }],
                  };
                } else {
                  return {
                    content: [{
                      type: "text",
                      text: `Permission DENIED: ${response.reason}\n\nThis request was determined to be outside acceptable policy. Try a different approach or contact the system operator.`,
                    }],
                  };
                }
              } catch {
                // Response file exists but isn't valid JSON yet, keep polling
              }
            }
          }

          return {
            content: [{
              type: "text",
              text: `Permission request submitted (ID: ${id}) but no response received within 60 seconds. The broker daemon may not be running. Your request has been saved and will be processed when the broker comes online.`,
            }],
          };
        },
      } as any;
    },
    { optional: true },
  );
}
