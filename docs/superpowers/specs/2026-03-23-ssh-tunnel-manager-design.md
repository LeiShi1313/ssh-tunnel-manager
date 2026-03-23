# SSH Tunnel Manager for macOS — Design Spec

## Overview

A macOS-native menu bar utility for managing SSH port forwarding. Built with Swift + SwiftUI, it shells out to the system `ssh` command, supports local/remote/dynamic forwarding, monitors tunnel health, auto-reconnects on failure, and persists configuration across launches.

## Architecture

**Single-process menu bar app** (Approach A). No daemon, no helper tools. The app lives entirely in the menu bar (`LSUIElement`), manages SSH child processes via `Process`, and stores config in a JSON file. SSH processes are independent — if the app restarts, auto-reconnect brings everything back.

**Target:** macOS 13+ (Ventura), Swift 5.9+, SwiftUI

## Menu Bar UI

**Status bar icon:** A small network/tunnel icon. Color indicates state:
- Gray: no active tunnels
- Green: all tunnels connected
- Yellow/Orange: some tunnels reconnecting
- Red: one or more tunnels failed

**Menu bar popover** (click the icon):
- Each tunnel row: name, forwarding summary (e.g. `L:5432 -> localhost:5432`), status dot, connect/disconnect toggle
- Right-click or swipe on a tunnel row: Edit, Duplicate, Delete
- Bottom bar: "+" button, gear icon for preferences

**No main window, no dock icon.**

## Data Model

### Tunnel Config

Stored in `~/Library/Application Support/SSHTunnelManager/tunnels.json`.

Each tunnel entry:

| Field | Type | Description |
|---|---|---|
| id | UUID | Unique identifier |
| name | String | User-friendly label (e.g. "Dev DB") |
| host | String | SSH server hostname/IP |
| port | Int | SSH port (default 22) |
| user | String | SSH username |
| authMethod | Enum | `key` or `password` |
| keyPath | String? | Path to SSH key (nil for password auth) |
| forwardingType | Enum | `local`, `remote`, or `dynamic` |
| localPort | Int | Local port to bind |
| remoteHost | String? | Remote host (not needed for dynamic) |
| remotePort | Int? | Remote port (not needed for dynamic) |
| autoConnect | Bool | Connect when app launches |
| enabled | Bool | Whether the tunnel is active in the config |

### App Preferences

Stored via `UserDefaults`:

- `launchAtLogin`: Bool (default false)
- `reconnectEnabled`: Bool (default true)
- `reconnectMaxRetries`: Int (default 0 = unlimited)
- Reconnect backoff schedule: 1s, 2s, 5s, 10s, 30s, 60s (cap)

### Password Storage

For password-auth tunnels, passwords are stored in the **macOS Keychain**, keyed by tunnel UUID. Never stored in the JSON config file.

## SSH Process Management

### Spawning Tunnels

Each tunnel runs as a separate `Process` executing the system `ssh` command:

- Local: `ssh -N -L <localPort>:<remoteHost>:<remotePort> <user>@<host> -p <port>`
- Remote: `ssh -N -R <remotePort>:<remoteHost>:<localPort> <user>@<host> -p <port>`
- Dynamic: `ssh -N -D <localPort> <user>@<host> -p <port>`

Standard flags: `-N` (no remote command), `-o ExitOnForwardFailure=yes`, `-o ServerAliveInterval=30`, `-o ServerAliveCountMax=3`

### Password Auth

Use `SSH_ASKPASS` environment variable pointing to a helper script that retrieves the password from Keychain. This avoids passwords visible in `ps` output. Set `DISPLAY=:0` and `SSH_ASKPASS_REQUIRE=force` to ensure `ssh` uses the askpass mechanism.

### Key Auth

Pass `-i <keyPath>`. If the key has a passphrase, rely on the system `ssh-agent`.

### Lifecycle Management

- `TunnelManager` class maps tunnel ID to process + state
- Monitor process termination via `terminationHandler`
- On unexpected termination (exit code != 0): trigger reconnect logic
- On intentional disconnect: send `SIGTERM`, wait briefly, then `SIGKILL` if needed
- On app quit: terminate all child processes cleanly

### Reconnect Logic

- Exponential backoff: 1s, 2s, 5s, 10s, 30s, 60s (cap at 60s)
- Post `UserNotification` on disconnect and on successful reconnect
- Track retry count per tunnel, reset on successful connection
- If max retries reached (and configured > 0): stop retrying, notify user

## App Lifecycle & Persistence

### Launch Behavior

- Registered as `LSUIElement` (Info.plist: `Application is agent` = YES)
- On launch: load `tunnels.json`, auto-connect tunnels with `autoConnect: true`
- Launch at login via `SMAppService.mainApp` (macOS 13+)

### Persistence

- Tunnel configs saved to disk on every change (add/edit/delete)
- Active tunnel states (which were connected) saved on quit, restored on relaunch
- On crash recovery: check `autoConnect` flags + last-known-active list to restore tunnels

### Port Conflict Handling

- Before spawning `ssh`, check if `localPort` is already in use (attempt `bind` on the port)
- If occupied: show notification with the conflicting port, mark tunnel as failed, don't retry

## UI Details

### Add/Edit Tunnel View

A small SwiftUI sheet with:
- Name (text field)
- SSH Host, Port, User
- Auth method picker (Key / Password)
  - Key: file picker for key path
  - Password: secure text field (saved to Keychain on save)
- Forwarding type picker (Local / Remote / Dynamic)
  - Local/Remote: local port, remote host, remote port fields
  - Dynamic: local port only
- Auto-connect toggle

### Preferences Window

- Launch at login toggle
- Reconnect settings (enable/disable, max retries)
- About / version info

### Notifications

- Tunnel disconnected: "Tunnel 'Dev DB' disconnected. Reconnecting..."
- Reconnect succeeded: "Tunnel 'Dev DB' reconnected."
- Reconnect failed (max retries): "Tunnel 'Dev DB' failed after X attempts. Click to retry."

## Future Considerations (Not in v1)

- Jump host / proxy command support (`-J`)
- Tunnel groups (start/stop multiple tunnels together)
- Import from `~/.ssh/config`
- Menu bar traffic indicators
