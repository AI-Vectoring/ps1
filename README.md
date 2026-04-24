# Git & GitHub Sync-Aware Bash Prompt

## Overview

Visually segmented Bash prompt that tracks local Git state and asynchronously verifies synchronization with GitHub. Designed for zero terminal lag, container compatibility, and minimal system overhead. The prompt renders instantly from a local cache; background jobs handle network verification without blocking the shell.

**No Nerd Fonts or Powerline fonts required.** Segments are rendered as adjacent colored blocks using standard ANSI 256-color codes. All status symbols (✓ ! ≠ ✗ ?) are plain Unicode present in every modern terminal font. The prompt looks identical across all terminals and environments.

---

## Features

- **Zero-Latency Rendering**: Prompt draws instantly by reading a local cache file. Network operations run asynchronously.
- **Async GitHub Sync Verification**: Checks if local disk state matches `origin` every 5 seconds (configurable).
- **Context-Aware Coloring**: Host segment adapts to Docker, SSH, or local environments. User segment highlights sudo privileges. Directory segment reflects Git working tree state.
- **Custom Display Name**: Set a human-readable name for any machine via `~/.ps1_hostname`, independent of the OS hostname.
- **Self-Contained Bash**: No external dependencies, no Node/Python/Ruby, no theme frameworks. Pure Bash + standard POSIX utilities.
- **Container & VPS Friendly**: Uses a single `/tmp` cache file. No subdirectories, no lock files, no root privileges required.
- **GitHub Rate Limit Safe**: Uses standard Git protocol (`git fetch`), not the GitHub REST/GraphQL API.

---

## Visual Layout & Status Indicators

The prompt is composed of four colored segments. Segments abut each other through ANSI color transitions — no separator character, no special font required:

```
[Host]  [User]  [Directory] [GitHub Symbol]  $
```

### Segment Color Mapping

| Condition | Segment | Color (ANSI 256) |
|-----------|---------|------------------|
| Local machine | Host background | Dark Blue (`25`) |
| Docker container | Host background | Dark Green (`28`) |
| SSH session | Host background | Dark Orange (`130`) |
| Sudo/wheel group | User text | Bold Yellow |
| Standard user | User text | Light Gray (`244`) |
| Not a Git repo | Directory text | Light Gray (`253`) |
| Git repo (clean) | Directory text | Bold Orange (`166`) |
| Git repo (dirty) | Directory text | Bold Golden (`178`) |
| All segments | Background | Dark Gray (`239`) |

### GitHub Sync Symbols

| Symbol | Color | Meaning |
|--------|-------|---------|
| `?` | Bold Yellow | Cache expired, first run, or fetch in progress |
| `✓` | Bold Green | Connected. Local disk matches `origin` exactly |
| `!` | Bold Yellow | Connected. Local disk differs from `origin` (ahead, behind, diverged, or uncommitted) |
| `≠` | Bold Red | Connection failed, timeout, or remote ref missing |
| `✗` | Bold Red | Git repo detected but `origin` is not a GitHub remote |

> Directory color tracks local working tree state. The symbol tracks disk vs remote state. They operate independently.

---

## Installation

Install on any machine with one command — no clone required:

```bash
curl -fsSL https://raw.githubusercontent.com/AI-Vectoring/ps1/master/ps1 | bash
```

This installs the `ps1` command to `~/.local/bin/ps1` and adds the following two lines to `~/.bashrc`:

```bash
# ps1 prompt — https://github.com/AI-Vectoring/ps1
source "/home/user/.local/bin/ps1" 2>/dev/null
```

The comment line is informational and can be freely edited or removed. The `source` line is the only functional anchor — it is what `ps1 --remove` and `ps1 --uninstall` locate and delete.

### Installer Options

| Option | Effect |
|--------|--------|
| *(no args)* | Install command + add to `.bashrc` |
| `-n, --name <name>` | Set display name for this machine (see below) |
| `-t, --try` | Install command, skip `.bashrc` |
| `-p, --permanent` | Add existing command to `.bashrc` |
| `-u, --update` | Re-download command + refresh `.bashrc` entry |
| `--remove` | Strip from `.bashrc`, keep command |
| `--uninstall` | Remove command + strip `.bashrc` |
| `--help` | Show help |

### Installed Command Options

Once installed, `ps1` can be run directly:

| Command | Effect |
|---------|--------|
| `ps1 -n <name>` | Set display name for this machine |
| `ps1 -u` | Update from GitHub |
| `ps1 -p` | Add to `.bashrc` |
| `ps1 --remove` | Strip from `.bashrc`, keep command |
| `ps1 --uninstall` | Remove completely |
| `ps1 vps <user@host> [-n <name>]` | Inject ps1 to a remote VPS via SSH |
| `ps1 docker <id> [-n <name>]` | Inject ps1 into a running Docker container |
| `ps1 --help` | Show help |

---

## Hostname & Display Name

By default the host segment shows `\h` (the system hostname). On some VPS providers the hostname is set to the IP address, and Docker containers show a short container ID. To override this without touching the OS hostname, set a display name:

```bash
ps1 -n my-server
```

This writes `my-server` to `~/.ps1_hostname`. The prompt reads this file on every render and falls back to `\h` if absent. The file survives updates and reinstalls. To clear it:

```bash
rm ~/.ps1_hostname
```

### Injecting to Remote Targets

ps1 can be deployed to remote machines from your local workstation without logging in first:

```bash
ps1 vps -n prod-server admin@192.168.1.100   # inject to a VPS via SSH
ps1 docker -n dev-db my-container-id         # inject into a running Docker container
```

These commands copy `ps1` and its logic to the target, add the source line to the target's `.bashrc`, and write the display name to `~/.ps1_hostname` on the target. The same two-line `.bashrc` pattern is used everywhere.

---

## Configuration

All defaults are defined at the top of `ps1-logic`:

```bash
SYNC_CACHE="/tmp/git-sync"     # Cache file path
SYNC_THROTTLE=5                # Seconds between async fetches
```

### Customizing Symbols & Colors

Modify the `SYM_*` variables in `ps1-logic`. Format: `\[\033[1;38;5;<COLOR>m\]<CHAR>`

- `1;` = Bold
- `38;5;` = 256-color foreground
- Example: change `!` to blue: `SYM_DIFF="\[\033[1;38;5;33m\]!"`

### Adjusting Refresh Frequency

| Value | Behaviour |
|-------|-----------|
| `1` | Aggressive — high network usage |
| `5` | Default — balanced |
| `30` | Conservative — minimal network |

---

## Architecture & Design Philosophy

### Async-First Rendering

1. `PROMPT_COMMAND` triggers `__generate_prompt()` on every newline.
2. The function reads `/tmp/git-sync` instantly (sub-millisecond).
3. If cache is older than `SYNC_THROTTLE`, it displays `?` and spawns a detached background job.
4. The background job runs `git fetch`, compares disk state, writes the result atomically, and exits. The terminal never waits.

### Why No Lock Files?

With a 5-second throttle and typical `git fetch` latency under 2 seconds, overlapping background jobs are rare, self-limiting, and harmless. The last job to finish overwrites the cache with the correct state.

### Atomic Cache Writes

`printf "X" > /tmp/git-sync` — on POSIX-compliant systems, file redirection with `printf` is atomic. The prompt will never read a partially written character.

---

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Stuck on `≠` | Auth prompt, firewall, or invalid SSH key | Test: `git fetch origin`. Fix SSH/HTTPS auth, then `rm -f /tmp/git-sync` |
| Flickering `?` / `≠` | Outdated script with premature `touch` | Update: `ps1 -u` |
| High CPU/network | `SYNC_THROTTLE` too low or rapid Enter in slow networks | Increase throttle to `10` or `15` |
| Host shows IP or CID | OS hostname not set | Run `ps1 -n <name>` to set a display name without touching the OS |

---

## Limitations

1. **Async Delay**: Symbol reflects remote state at the time of the last successful fetch. Maximum staleness equals `SYNC_THROTTLE` + fetch latency.
2. **Single Remote**: Only evaluates `origin`. Multi-remote setups require manual modification.
3. **Commit vs Disk**: `git diff --quiet origin/$BRANCH` compares working directory + untracked files against remote. Local commit history is signaled by directory color.
4. **No Push Notifications**: Pull-based only. Cannot detect GitHub changes without a fetch cycle.
5. **Bash Only**: Not compatible with Zsh/Fish without syntax translation.

---

## License

MIT — see [LICENSE](LICENSE).
