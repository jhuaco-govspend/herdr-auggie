# herdr-auggie

[Herdr](https://herdr.dev) plugin for [Auggie](https://docs.augmentcode.com/cli/overview), the Augment Code CLI.

Herdr is a terminal multiplexer for coding agents: panes, tabs, mouse support, and a sidebar that shows what each agent is doing. It detects about twenty agents out of the box, but not Auggie. Without this plugin Herdr treats Auggie as a plain program: it can't tell whether Auggie is thinking, done or waiting for you, and a Herdr restart loses the conversation.

## Features

| Feature | What you get |
| --- | --- |
| Live state | Each Auggie pane shows up in the sidebar as `working` (thinking or running a tool), `idle` (your turn) or `blocked` (waiting for a tool approval) |
| Session name | The sidebar shows `auggie · <session name>`, using the name Auggie generates after the first exchange (or the one you set when renaming the session). Also available as the `$session` token for custom sidebar rows |
| Approval detection | The pane switches to `blocked` within a second or two of Auggie showing "Tool Approval Required", and back to `working` once you answer |
| Resume after restart | When the Herdr server restarts (reboot, crash, `herdr server stop`), every pane that was running Auggie reopens its conversation with the full history |
| New session | One shortcut opens a new tab running Auggie in the current directory |
| Session picker | A popup lists the saved Auggie sessions for the current directory; Enter resumes the selected one in a new tab |
| Self-healing hooks | If another tool rewrites `~/.augment/settings.json`, the plugin reinstalls its hooks the next time Herdr starts |

## Platforms

| Platform | Status |
| --- | --- |
| Linux | Supported, tested (Herdr 0.9.1, Auggie 0.36) |
| Windows | Through WSL2 only (install and run everything inside WSL). Native Windows Herdr is not supported: the plugin is bash |
| macOS | Should work (portable bash, BSD `date` fallbacks), not tested yet |

On Windows use Windows Terminal as the outer terminal. Herdr has an open bug with Warp where Auggie's input box renders inside the scrollback ([herdr#3872](https://github.com/herdrdev/herdr/issues/3872)).

## Requirements

- Herdr 0.9 or newer
- Auggie CLI, logged in (`auggie login`)
- `jq`
- `fzf`, optional: the session picker falls back to a numbered menu without it
- `perl`, macOS only (ships with the OS)

## Install

### 1. Herdr

```sh
curl -fsSL https://herdr.dev/install.sh | sh
```

This installs a single binary to `~/.local/bin/herdr`. If that directory is not on your `PATH`, add it to your shell rc:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### 2. The plugin

```sh
herdr plugin install jhuaco-govspend/herdr-auggie
```

The install adds the plugin's hooks to `~/.augment/settings.json`. Existing hooks are kept, and the previous file is saved as `settings.json.bak.herdr-auggie`. The hooks do nothing outside Herdr (they check `HERDR_ENV=1`), so running `auggie` in a normal terminal is unaffected.

To work on the plugin itself, link a local clone instead. `link` does not run the install step, so add the hooks by hand, and run `install-hooks.sh` again after editing anything under `hooks/`:

```sh
git clone https://github.com/jhuaco-govspend/herdr-auggie.git ~/herdr-auggie
herdr plugin link ~/herdr-auggie
bash ~/herdr-auggie/scripts/install-hooks.sh
```

### 3. Shortcuts

Plugins can't register shortcuts, so add these to `~/.config/herdr/config.toml` (create the file if it doesn't exist):

```toml
[[keys.command]]
key = "prefix+a"
type = "shell"
command = "herdr plugin action invoke new --plugin auggie"

[[keys.command]]
key = "prefix+shift+a"
type = "shell"
command = "herdr plugin pane open --plugin auggie --entrypoint sessions"
```

Apply them without restarting: `herdr server reload-config`.

## Usage

Start Herdr from the project you want to work on:

```sh
cd ~/code/my-repo
herdr
```

The Herdr prefix is `ctrl+b`, as in tmux.

| Shortcut | Action |
| --- | --- |
| `ctrl+b`, then `a` | New tab with Auggie in the current directory |
| `ctrl+b`, then `shift+a` | Session picker for the current directory |

Auggie started any other way inside a Herdr pane (typing `auggie` in a shell) is tracked too. The shortcuts are just a convenience.

The plugin actions are also available from the command line or Herdr's plugin action list:

```sh
herdr plugin action invoke new --plugin auggie              # new session
herdr plugin action invoke resume-all --plugin auggie       # resume interrupted sessions now
herdr plugin action invoke install-hooks --plugin auggie
herdr plugin action invoke uninstall-hooks --plugin auggie
```

Extra Auggie flags for new and resumed sessions go in `AUGGIE_HERDR_ARGS`, for example `export AUGGIE_HERDR_ARGS="--model sonnet5-high"`.

### Sidebar layout

By default Herdr shows `workspace · tab` on the first line and the agent label on the second, which the plugin turns into `auggie · <session name>`. For a new session the name shows up a few seconds after the first answer, once Auggie has generated it.

To lay the rows out differently, use the `$session` token in `~/.config/herdr/config.toml`:

```toml
[ui.sidebar.agents.rows_by_agent]
auggie = [["state_icon", "workspace", "tab"], ["$session"]]
```

## Check that it works

1. **State.** Press `ctrl+b`, `a`. A tab opens with Auggie and the sidebar shows `auggie` as `idle`. Ask it something; it shows `working` while it runs and `idle` when it's done.
2. **Blocked.** Ask for something that needs approval, like a shell command outside your allowlist. When "Tool Approval Required" appears, the sidebar switches to `blocked`. Approve and it goes back to `working`.
3. **Resume.** After at least one exchange, run `herdr server stop`, then `herdr`. After a few seconds the tab comes back running Auggie with the conversation history.
4. **Picker.** Press `ctrl+b`, `shift+a`. A popup lists the sessions for the current directory.

## Troubleshooting

```sh
herdr plugin list                        # should show: auggie ... enabled
herdr plugin log                         # output and errors from the plugin's startup commands
jq '.hooks | keys' ~/.augment/settings.json   # should include SessionStart, PromptSubmit, Stop...
```

- **No state in the sidebar**: Auggie has to run inside a Herdr pane. Check the hooks with the `jq` command above and reinstall them with `herdr plugin action invoke install-hooks --plugin auggie`.
- **Hooks keep disappearing**: another tool (a dotfiles setup script, for example) is rewriting `~/.augment/settings.json`. The plugin reinstalls them on every Herdr start; run `herdr plugin action invoke install-hooks --plugin auggie` to fix it right away.
- **A pane doesn't resume**: Auggie only saves a session after the first exchange. Empty sessions restart as a fresh Auggie.
- **Debug log**: start Auggie with `HERDR_AUGGIE_DEBUG=1 auggie` and every hook event is appended to `~/.local/state/herdr-auggie/<session>/debug.log`.
- **Indexing prompt on every new session**: the plugin always passes `--allow-indexing`. If you launch Auggie by hand in a new directory, accept the prompt once.

## Uninstall

```sh
herdr plugin action invoke uninstall-hooks --plugin auggie
herdr plugin uninstall auggie     # or: herdr plugin unlink auggie, for a linked clone
```

Remove the two `[[keys.command]]` blocks from `~/.config/herdr/config.toml`.

## How it works

`install-hooks.sh` copies the two hook scripts to `~/.local/share/herdr-auggie/hooks/` and registers that copy in `~/.augment/settings.json`, so the path stays valid wherever Herdr keeps the plugin. Every Herdr start refreshes the copy.

`hooks/auggie-herdr-hook.sh` runs on Auggie's `SessionStart`, `PromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop` and `SessionEnd` hooks and reports each state to Herdr with `herdr pane report-agent --source custom:auggie`.

Auggie has no hook that fires while it waits for approval. On `PreToolUse` the hook starts `hooks/approval-watch.sh`, which reads the pane once a second until that tool call finishes and reports `blocked` while the approval dialog is visible.

Herdr only resumes agents that have an official integration, so the hook keeps its own map of pane to conversation in `~/.local/state/herdr-auggie/<session>/`. On plugin startup, `scripts/resume.sh` reads that map and relaunches `auggie --resume <id>` in each pane that came back without an agent.

| Path | Role |
| --- | --- |
| `herdr-plugin.toml` | Plugin manifest: build step, startup commands, actions, session picker popup |
| `hooks/auggie-herdr-hook.sh` | Translates Auggie hook events into Herdr agent state |
| `hooks/approval-watch.sh` | Detects the approval dialog while a tool call is pending |
| `scripts/install-hooks.sh` | Copies the hooks to `~/.local/share/herdr-auggie` and adds or removes them in `~/.augment/settings.json` (idempotent) |
| `scripts/resume.sh` | Relaunches interrupted conversations |
| `scripts/new-session.sh` | Opens a tab running Auggie |
| `scripts/sessions.sh` | Session picker |

## Limitations

- Approval detection matches the text "Tool Approval Required". If Auggie changes that dialog, `blocked` stops showing and the pane stays `working`.
- Auggie's `Notification` hook exists in its schema but does not fire in 0.36, so the approval dialog is the only "needs input" signal.
- The session picker does not check whether a conversation is already open in another pane, so the same conversation can end up running in two tabs.
- Resume depends on Herdr restoring the pane layout. Panes that don't come back get a new workspace in the same directory.

## License

[Apache-2.0](LICENSE), the same license as Herdr.
