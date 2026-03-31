#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import process from "node:process";

const root = process.cwd();
const checkOnly = process.argv.includes("--check");

function readText(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function git(command) {
  return execSync(command, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
}

function replaceBlock(text, name, body) {
  const start = `<!-- ${name}:start -->`;
  const end = `<!-- ${name}:end -->`;
  const pattern = new RegExp(`${escapeRegExp(start)}[\\s\\S]*?${escapeRegExp(end)}`, "m");
  const replacement = `${start}\n${body}\n${end}`;
  if (!pattern.test(text)) {
    throw new Error(`Missing marker block ${name}`);
  }
  return text.replace(pattern, replacement);
}

function escapeRegExp(text) {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function bulletList(items) {
  return items.map((item) => `- ${item}`).join("\n");
}

function codeBlock(language, lines) {
  return `\`\`\`${language}\n${lines.join("\n")}\n\`\`\``;
}

function phaseLine(phase) {
  const marker = phase.state === "done" ? "[x]" : phase.state === "active" ? "[~]" : "[ ]";
  return `- ${marker} Phase ${phase.id}: ${phase.title}`;
}

// Generated status docs come from versioned hyperdata plus live git state so the
// repo can auto-refresh progress surfaces without hiding the source of truth.
const data = JSON.parse(readText("status/hyperdata.json"));
const head = git("git rev-parse HEAD");
const shortHead = head.slice(0, 8);
const branch = git("git rev-parse --abbrev-ref HEAD");
const recentCommits = git("git log --oneline -n 8")
  .split("\n")
  .filter(Boolean)
  .map((line) => `- \`${line.slice(0, 8)}\` ${line.slice(9)}`);

const completedPhases = data.phases.filter((phase) => phase.state === "done");
const activePhases = data.phases.filter((phase) => phase.state === "active");
const openPhases = data.phases.filter((phase) => phase.state === "open");

const readmePath = "README.md";
const readme = readText(readmePath);
let nextReadme = readme;
nextReadme = replaceBlock(nextReadme, "status:auto:focus", bulletList(data.focus));
nextReadme = replaceBlock(nextReadme, "status:auto:status", bulletList(data.status));
nextReadme = replaceBlock(
  nextReadme,
  "status:auto:progress-surfaces",
  bulletList(data.progress_surfaces.map((item) => `[${item.label}](/Users/s3nik/Desktop/blender-zig/${item.path})`)),
);
nextReadme = replaceBlock(nextReadme, "status:auto:reference-helpers", bulletList(data.reference_helpers));
nextReadme = replaceBlock(nextReadme, "status:auto:quick-start", codeBlock("bash", data.quick_start));
nextReadme = replaceBlock(
  nextReadme,
  "status:auto:cli-usage",
  codeBlock("text", [`blender-zig <${data.cli_commands.join("|")}> [output.obj]`]),
);

const nextProgress = `# Progress

> Generated from \`status/hyperdata.json\` and git state. Refresh with \`npm run status:update\`.

## Hypertime Snapshot

- branch: \`${branch}\`
- head: \`${shortHead}\`
- source: \`status/hyperdata.json\`

Artifacts:
${bulletList(data.progress_surfaces.map((item) => `\`${item.path}\``))}

## Current State

\`blender-zig\` is a runnable Zig CLI on macOS and a staged rewrite workspace for Blender-inspired geometry systems.

Completed phases:
${bulletList(completedPhases.map((phase) => `Phase ${phase.id}: ${phase.title}`))}

Active phases:
${activePhases.length > 0 ? bulletList(activePhases.map((phase) => `Phase ${phase.id}: ${phase.title}`)) : "- none"}

Open phases:
${openPhases.length > 0 ? bulletList(openPhases.map((phase) => `Phase ${phase.id}: ${phase.title}`)) : "- none"}

## Pushed Commits

${recentCommits.join("\n")}

## What Runs Today

${bulletList(data.runs_today.map((item) => `\`${item}\``))}

## Next Targets

${bulletList(data.next_targets)}

## Readout

${data.notes.join("\n")}
`;

const nextRoadmap = `# Roadmap

> Generated from \`status/hyperdata.json\` and git state. Refresh with \`npm run status:update\`.

## Active Head

- branch: \`${branch}\`
- head: \`${shortHead}\`

## Phase Map

${data.phases.map(phaseLine).join("\n")}

## Current Targets

${bulletList(data.next_targets)}

## Detailed Backlog

- [tasks/zig-rewrite.md](/Users/s3nik/Desktop/blender-zig/tasks/zig-rewrite.md)
`;

const outputs = [
  { path: readmePath, content: nextReadme },
  { path: "progress.md", content: nextProgress },
  { path: "ROADMAP.md", content: nextRoadmap },
];

const changed = [];
for (const output of outputs) {
  const absolutePath = path.join(root, output.path);
  const current = fs.existsSync(absolutePath) ? fs.readFileSync(absolutePath, "utf8") : "";
  if (current !== output.content) {
    changed.push(output.path);
    if (!checkOnly) {
      fs.writeFileSync(absolutePath, output.content);
    }
  }
}

if (checkOnly && changed.length > 0) {
  console.error(`status docs out of date: ${changed.join(", ")}`);
  process.exit(1);
}

if (!checkOnly && changed.length > 0) {
  console.log(`updated: ${changed.join(", ")}`);
}
