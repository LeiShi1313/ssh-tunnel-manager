# SSH Tunnel Manager

A lightweight macOS menu bar app for managing SSH port forwarding. Configure tunnels, monitor their status, and let them auto-reconnect — all from your status bar.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Menu bar native** — no dock icon, no main window, lives in your status bar
- **Local, Remote, and Dynamic (SOCKS) forwarding** — `-L`, `-R`, `-D`
- **Auto-reconnect** — exponential backoff (1s → 60s), with notifications
- **Persistent config** — tunnels survive app restarts
- **Minimal setup** — only 4 fields needed: name, host, local port, remote port
- **Status at a glance** — icon color shows tunnel health (green/yellow/red/gray)
- **Keychain integration** — passwords stored securely, never in config files
- **Launch at login** — optional, via System Settings

## Install

### From source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
git clone https://github.com/LeiShi1313/ssh-tunnel-manager.git
cd ssh-tunnel-manager
brew install xcodegen
xcodegen generate
xcodebuild -project SSHTunnelManager.xcodeproj -scheme SSHTunnelManager -configuration Release build
```

Then copy the built app to Applications:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/SSHTunnelManager-*/Build/Products/Release/SSHTunnelManager.app /Applications/
```

## Usage

1. Click the network icon in your menu bar
2. Click **+** to add a tunnel
3. Fill in: **Name**, **SSH Host**, **Local Port**, **Remote Port**
4. Click **Add** — the tunnel connects automatically

That's it. Username defaults to your macOS user, SSH auth uses your default keys via ssh-agent.

### Advanced options

Right-click a tunnel → **Edit**, or expand **Advanced** in the form to configure:

- Custom username or SSH port
- Remote host (defaults to `localhost`)
- Forwarding type (Local/Remote/Dynamic)
- SSH key path or password auth
- Auto-connect on launch

### Status colors

| Icon Color | Meaning |
|------------|---------|
| Gray | No active tunnels |
| Green | All tunnels connected |
| Orange | Some tunnels reconnecting |
| Red | One or more tunnels failed |

## How it works

Each tunnel spawns a system `ssh` process with flags like:

```
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 5432:localhost:5432 user@host
```

Config is stored in `~/Library/Application Support/SSHTunnelManager/tunnels.json`. Passwords use the macOS Keychain.

## License

MIT
