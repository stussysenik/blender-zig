#!/usr/bin/env node

import { execSync } from "node:child_process";
import process from "node:process";

function git(command) {
  return execSync(command, {
    cwd: process.cwd(),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "ignore"],
  }).trim();
}

const branch = git("git rev-parse --abbrev-ref HEAD");
const head = git("git rev-parse HEAD");
const shortHead = head.slice(0, 8);
const aheadBehind = git("git rev-list --left-right --count @{upstream}...HEAD");
const [behind, ahead] = aheadBehind.split(/\s+/);
const recentCommits = git("git log --oneline -n 8")
  .split("\n")
  .filter(Boolean);

console.log(`# Live Status

- branch: \`${branch}\`
- head: \`${shortHead}\`
- ahead: \`${ahead}\`
- behind: \`${behind}\`

## Recent Commits
${recentCommits.map((line) => `- \`${line.slice(0, 8)}\` ${line.slice(9)}`).join("\n")}
`);
