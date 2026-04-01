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

function tryGit(command) {
  try {
    return git(command);
  } catch {
    return null;
  }
}

const rawBranch = git("git rev-parse --abbrev-ref HEAD");
const head = git("git rev-parse HEAD");
const shortHead = head.slice(0, 8);
const branch = rawBranch === "HEAD" ? `detached@${shortHead}` : rawBranch;
const upstream = tryGit("git rev-parse --abbrev-ref --symbolic-full-name @{upstream}");
const aheadBehind = upstream ? git("git rev-list --left-right --count @{upstream}...HEAD") : null;
const [behind, ahead] = aheadBehind ? aheadBehind.split(/\s+/) : ["n/a", "n/a"];
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
