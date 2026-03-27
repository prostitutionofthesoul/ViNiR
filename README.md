<p align="center">
  <img src="https://github.com/user-attachments/assets/887b70e4-5835-42db-a2f2-4cd726c378ae" alt="ViNiR Desktop Preview" width="800">
</p>

<h1 align="center">ViNiR</h1>

<p align="center">
  <b>A complete desktop shell built on Quickshell for the Niri compositor</b><br>
</p>

---

## Quick Start

```bash
git clone https://github.com/prostitutionofthesoul/ViNiR.git
cd ViNiR
./setup install       # Interactive — asks before each step
./setup install -y    # Automatic — installs everything without prompts 
```

The installer handles dependencies, configs, theming — everything.

**Updating:**

```bash
./setup update        # Check remote, pull, sync, restart shell
```

Or run `./setup` with no arguments for the interactive TUI menu where you can update, migrate, rollback, diagnose, and more.

Your configs stay untouched. New features come as optional migrations. Rollback included if something breaks (`./setup rollback`).

---

## Keybinds

| Key | Action |
|-----|--------|
| `Super+A` | Overview — search apps, navigate workspaces |
| `Alt+Tab` | Window switcher |
| `Super+V` | Clipboard history |
| `Super+Shift+S` | Screenshot region |
| `Super+Shift+X` | OCR region |
| `Super+,` | Settings |
| `Super+Shift+W` | Switch panel family |

---

## Troubleshooting

```bash
qs log -c ii                    # Check logs — the answer is usually here
qs kill -c ii && qs -c ii       # Restart the shell
./setup doctor                  # Auto-diagnose and fix common problems
./setup rollback                # Undo the last update
```
