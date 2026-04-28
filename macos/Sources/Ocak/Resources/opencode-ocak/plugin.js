// Ocak plugin for OpenCode — sends session events to Ocak's hook server.
// Installed to ~/.config/opencode/plugins/ocak.js
// version: 1.1.0

const OCAK_HOOK_PORT = process.env.OCAK_HOOK_PORT || "27832"
const OCAK_HOOK_URL = `http://localhost:${OCAK_HOOK_PORT}/hook`

function sendEvent(eventName, cwd) {
  const ocakId = process.env.OCAK_SESSION_ID
  if (!ocakId) return

  const body = JSON.stringify({
    hook_event_name: eventName,
    session_id: "",
    cwd: cwd || "",
  })

  fetch(OCAK_HOOK_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Ocak-Session": ocakId,
    },
    body,
  }).catch(() => {})
}

export const OcakPlugin = async () => {
  return {
    event: async ({ event }) => {
      const ocakId = process.env.OCAK_SESSION_ID
      if (!ocakId) return

      const cwd = event.properties?.info?.directory
        || event.properties?.directory
        || event.properties?.cwd
        || process.cwd()

      switch (event.type) {
        case "session.created":
          sendEvent("SessionStart", cwd)
          break

        case "session.status": {
          const statusType = event.properties?.status?.type ?? event.status?.type
          if (statusType === "busy" || statusType === "retry") {
            sendEvent("UserPromptSubmit", cwd)
          } else if (statusType === "idle") {
            sendEvent("SessionEnd", cwd)
          }
          break
        }

        case "tool.execute.after":
        case "tool.execute.before":
          sendEvent("PostToolUse", cwd)
          break

        case "permission.asked":
          sendEvent("PermissionRequest", cwd)
          break

        case "permission.replied":
          sendEvent("TaskCompleted", cwd)
          break

        case "session.idle":
          sendEvent("SessionEnd", cwd)
          break

        case "session.deleted":
          sendEvent("SessionEnd", cwd)
          break

        case "session.error":
          sendEvent("StopFailure", cwd)
          break
      }
    },
  }
}
