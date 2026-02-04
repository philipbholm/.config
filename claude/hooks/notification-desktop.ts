#!/usr/bin/env npx tsx

import { execSync } from "child_process";

interface NotificationHookInput {
  hook_event_name: "permission_prompt" | "idle_prompt";
  transcript_path?: string;
  session_id?: string;
}

async function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => (data += chunk));
    process.stdin.on("end", () => resolve(data));
  });
}

function sendMacNotification(title: string, message: string): void {
  try {
    execSync(`terminal-notifier -title "${title}" -message "${message}" -sound Ping`);
  } catch {
    // Silently fail - notifications are not critical
  }
}

async function main(): Promise<void> {
  try {
    const input = await readStdin();
    const data: NotificationHookInput = JSON.parse(input);

    switch (data.hook_event_name) {
      case "permission_prompt":
        sendMacNotification(
          "Claude Code - Permission Required",
          "Claude needs your permission to proceed"
        );
        break;
      case "idle_prompt":
        sendMacNotification(
          "Claude Code - Ready",
          "Claude is waiting for your input"
        );
        break;
    }
  } catch {
    // Silently fail - don't interrupt Claude's workflow
  }
}

main();
