# Git & GitHub Sync-Aware Bash Prompt

## Overview
Visually segmented Bash prompt.
- Tracks local Git state and asynchronously verifies synchronization with GitHub. Designed for zero terminal lag, container compatibility, and minimal system overhead. The prompt renders instantly using local cache, while background jobs handle network verification without blocking your shell.

---

## Features
- **Zero-Latency Rendering**: Prompt draws instantly by reading a local cache file. Network operations run asynchronously.
- **Async GitHub Sync Verification**: Automatically checks if your local disk state matches the `origin` remote every 5 seconds (configurable).
- **Context-Aware Coloring**: Host segment adapts to Docker, SSH, or local environments. User segment highlights sudo privileges. Directory segment reflects Git working tree state.
- **Self-Contained Bash**: No external dependencies, no Node/Python/Ruby, no theme frameworks. Pure Bash + standard POSIX utilities.
- **Container & VPS Friendly**: Uses a single `/tmp` cache file. No subdirectories, no lock files, no root privileges required.
- **GitHub Rate Limit Safe**: Uses standard Git protocol (`git fetch`), not the GitHub REST/GraphQL API. Zero impact on developer rate limits.

---

## Visual Layout & Status Indicators

The prompt is composed of four visual segments separated by Powerline-style triangles (``):
```
[Host]  [User]  [Directory] [GitHub Symbol]  [Command Input]
```

### Segment Color Mapping
| Condition | Segment | Color (ANSI) |
|-----------|---------|--------------|
| Local machine | Host Background | Dark Blue (`25`) |
| Docker container | Host Background | Dark Green (`28`) |
| SSH session | Host Background | Dark Orange (`130`) |
| Sudo/wheel group | User Text | Bold Yellow (`33`) |
| Standard user | User Text | Light Gray (`244`) |
| Not a Git repo | Directory Text | Light Gray (`253`) |
| Git repo (clean) | Directory Text | Bold Orange (`166`) |
| Git repo (dirty/uncommitted) | Directory Text | Bold Golden (`178`) |
| All segment backgrounds | Triangles/Backgrounds | Dark Gray (`239`) |

### GitHub Sync Symbols
| Symbol | Color | Meaning |
|--------|-------|---------|
| `?` | Bold Yellow | Default state. Cache expired, first run, or fetch in progress. |
| `✓` | Bold Green | Connected successfully. Disk state matches `origin` exactly. |
| `!` | Bold Yellow | Connected successfully. Disk state differs from `origin` (ahead, behind, diverged, or uncommitted changes). |
| `≠` | Bold Red | Connection failed, timeout, or remote ref missing. |
| `✗` | Bold Red | Git repository detected, but `origin` is not a GitHub remote. |

> **Note**: The directory text color tracks *local working tree state*. The symbol tracks *disk vs remote state*. They operate independently.

---

## Architecture & Design Philosophy

### Async-First Rendering
Bash prompts block the terminal during execution. To prevent 1–3 second hangs from `git fetch`, this script decouples rendering from network I/O:
1. `PROMPT_COMMAND` triggers `__generate_prompt()` on every newline.
2. The function reads `/tmp/git-sync` instantly (sub-millisecond).
3. If cache is older than `SYNC_THROTTLE`, it displays `?` and spawns a detached background job.
4. The background job runs `git fetch`, compares disk state, writes the result atomically, and exits. The terminal never waits.

### Why No Lock Files?
Lock files prevent job accumulation during rapid prompt rendering. However, background Bash subshells `( ... ) &` run in isolated process spaces. Cross-process synchronization requires filesystem state, which adds complexity and fragility in read-only or ephemeral environments. With a 5-second throttle and typical `git fetch` latency under 2 seconds, overlapping jobs are rare, self-limiting, and harmless. The last job to finish simply overwrites the cache with the correct state.

### Atomic Cache Writes
The background job uses `printf "X" > /tmp/git-sync`. On POSIX-compliant systems, file redirection with `printf` is atomic. The prompt will never read a partially written character or encounter race-condition corruption.

### History Expansion Safety
Bash interprets `!` as history expansion by default. The script disables this globally at load time with `set +H`. **Do not paste the script interactively into your terminal**; source it from a file to avoid premature expansion errors.

---

## Installation

### 1. Save to File
Create a dedicated prompt file (recommended over inline `.bashrc` edits):
```bash
nano ~/.bash_prompt.sh
# Paste the entire script here
```

### 2. Source in `.bashrc`
Add the following to `~/.bashrc` or `~/.bash_profile`:
```bash
if [[ -f ~/.bash_prompt.sh ]]; then
    source ~/.bash_prompt.sh
fi
```

### 3. Apply & Clear Stale Cache
```bash
source ~/.bashrc
rm -f /tmp/git-sync
```

---

## Configuration

All defaults are defined at the top of the script for easy modification:

```bash
# --- DEFAULTS ---
SYNC_CACHE="/tmp/git-sync"     # Single cache file path
SYNC_THROTTLE=5                # Seconds between async fetches
```

### Customizing Symbols & Colors
Modify the ANSI escape sequences in the `SYM_*` variables. Format: `\[\033[1;38;5;<COLOR>m\<CHAR>]`
- `1;` = Bold
- `38;5;` = 256-color foreground
- Example: Change `!` to blue: `SYM_DIFF="\[\033[1;38;5;33m\]!"`

### Adjusting Refresh Frequency
Change `SYNC_THROTTLE=5` to your preference:
- `1` = Aggressive (high network usage)
- `5` = Default (balanced)
- `30` = Conservative (minimal network)

---

## Technical Deep Dive

### State Machine Flow
1. **Prompt Triggered** → Check `git rev-parse --is-inside-work-tree`
2. **Git Detected** → Check `git remote get-url origin` for `github.com`
3. **GitHub Remote Found** → Check cache age via `stat -c %Y`
4. **Cache Expired/Missing** → Display `?`, spawn async job, `disown`
5. **Async Job** → `timeout 4 git fetch origin`, `git diff --quiet origin/$BRANCH`, `git ls-files --others`
6. **Write Result** → `printf "✓/!/≠" > $SYNC_CACHE`
7. **Next Prompt** → Reads fresh cache, displays correct symbol instantly

### Network Protocol
`git fetch` uses SSH or HTTPS Git transport. It does not query `api.github.com`. GitHub's published API rate limits (5,000/hr authenticated) **do not apply**. Git operations are only throttled for extreme abuse (thousands of concurrent connections).

### Filesystem Assumptions
- `/tmp` must be writable. This is standard on all mainstream Linux distributions, VPS images, and container runtimes.
- If `/tmp` is unwritable, the async job fails silently. The prompt falls back to displaying `?` indefinitely until the filesystem is accessible.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `bash: !: event not found` | Interactive paste triggered history expansion | Always source from a file. `set +H` is included but only applies on load. |
| Symbol shows `*` instead of `?` | Terminal font rendering fallback | Verify with `echo "?"`. Change terminal font/size if it renders incorrectly. |
| Stuck on `≠` | Network auth prompt, firewall, or invalid SSH key | Test manually: `git fetch origin`. Fix SSH/HTTPS auth, then clear cache: `rm -f /tmp/git-sync` |
| Flickering between `?` and `≠` | Outdated script version with premature `touch` | Ensure you're using the final version with `printf` atomic writes and no `touch` in the async block. |
| High CPU/Network usage | `SYNC_THROTTLE` set too low, or rapid `Enter` spam in slow networks | Increase throttle to `10` or `15`. Background jobs self-limit naturally. |

---

## Limitations & Considerations

1. **Async Delay**: The symbol reflects remote state at the time of the last successful fetch, not live millisecond-by-millisecond state. Maximum staleness equals `SYNC_THROTTLE` + fetch latency.
2. **Single Remote Assumption**: Only evaluates `origin`. Multi-remote setups require manual modification to specify which remote to track.
3. **Commit vs Disk**: `git diff --quiet origin/$BRANCH` compares your working directory + untracked files against the remote. It intentionally ignores local commit history, as local Git state is already signaled by directory text color.
4. **No Webhooks/Push Notifications**: This is a pull-based status indicator. It cannot detect GitHub changes without a `fetch` cycle.
5. **Bash Only**: Not compatible with Zsh/Fish without syntax translation (PS1 vs PROMPT, `PROMPT_COMMAND` vs `precmd`, etc.).

---

## License
Provided as-is for personal and professional use. Modify, distribute, and adapt freely. No warranty expressed or implied.
