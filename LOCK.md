# LOCK convention

`.autopilot/LOCK` is a concurrency guard — NOT this file. This file documents the convention; the actual lock file is plain `LOCK` (no extension) and is created/removed by the loop.

Rules (enforced by PROMPT.md boot step 3):
- On boot, create `.autopilot/LOCK` with two lines: `pid: <n>` and `started: <ISO-8601>`.
- If `.autopilot/LOCK` already exists and `started` is <90 min old → another instance is active → exit immediately (no state writes).
- If >90 min old → assume crashed, overwrite.
- On exit (exit-contract), remove `.autopilot/LOCK`.

The lock uses the filesystem alone — no external lock server, no inotify, no fcntl. Works identically on Windows, macOS, Linux, and container mounts.
