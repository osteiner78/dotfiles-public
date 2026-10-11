# 001 — Karabiner/Goku template cleanup (2026-10-11)

Session closed. This report is the handoff for the next coding agent.

## Context
- Config: `common-macos/karabiner/.config/karabiner.edn`, symlinked as `~/.config/karabiner.edn`. `watchexec ... goku` recompiles it to `~/.config/karabiner/karabiner.json` on every save, so an edit is live within seconds. The user often has the edn open in nvim; tell them to `:e` after you edit.
- Script: `common-macos/bin/launch-focus`. If the app is running, it runs `osascript ... activate`. If not, it runs `open -a/-b`, polls until the app is running, then activates it.
- Versions: Karabiner-Elements 16.3.0, Goku 0.8.0, Ghostty 1.3.1, macOS 15.8.1.
- User: not a professional developer. Wants surgical changes, no comments by default, and commits only when asked. Global rules are in `~/.claude/CLAUDE.md`.

## What was done (commits)
| Commit | Change |
|---|---|
| `52ed230` | Added `launch-focus` as-is. It was untracked, and this gives the change history. |
| `167792b` | Template cleanup; see below. |
| `ee04269` | Hyper+d runs `/usr/bin/shortcuts run "Toggle Dark Mode"` instead of `dark-mode`. |
| `a53204a` | `karabiner-cheatsheet-gen` labels `shortcuts run "X"` commands as "x". Dropped the now-unused `bash -lc` stripping. |

`167792b` and `ee04269` were built from HEAD plus only the agent's edits, via a temporary `GIT_INDEX_FILE`, followed by `git reset -- <path>`. The user's own uncommitted and staged work was left untouched.

### `167792b` in detail
- Removed the `:sh` template (`/usr/bin/env bash -lc "%s"`) and its commented duplicate. Hyper+d and Hyper+/ became plain strings (Goku turns a string into `shell_command`).
- Removed `:focus_front` and `:focus_bid_front`. Calendar/Gmail/Claude/Gemini now use `:focus`; VSCode/WhatsApp use `:focus_bid`.
- `launch-focus`: removed `--front` and the `open -g` branch; the cold path is always `open -a` / `open -b`. The poll-then-activate loop was kept.
- Templates now: `:launch`, `:launch_new`, `:focus`, `:focus_bid`.
- Deliberately unchanged:
  - Hyper+q stays `open -n -a Ghostty`. The user wants a separate instance per window.
  - Hyper+f stays `open -a /System/Library/CoreServices/Finder.app`.

## Findings
1. **Karabiner's command environment.** Karabiner runs `shell_command` through `sh` with `PATH=/usr/bin:/bin:/usr/sbin:/sbin`; `HOME`, `USER` and `SHELL=/bin/zsh` are set. `$HOME` passes through Goku literally into `karabiner.json` and is expanded by `sh`.
2. **`bash -l` added nothing.** The login shell only adds cargo, LM Studio and `/usr/local/bin`. Homebrew and conda are configured for zsh only. The cheatsheet generator resolved `/usr/bin/python3` (3.9.6) both ways and produced byte-identical output.
3. **`--front` was a yabai-era leftover.** In the old `yabai-launch-focus`, background launch plus yabai window focus made sense. Without yabai, background launch only adds risk: the early `activate` can fail with `-609 Connection is invalid` (seen in the Karabiner log for Claude), leaving the app hidden.
   - Cold-start test: Arc, Obsidian, Paperless-ngx and Todoist, each in both modes, launched with Ghostty frontmost.
   - All 8 runs exited 0 and the app was frontmost through t+4 s.
   - Foreground launch was faster every time (Todoist 0.76 s vs 3.06 s).
   - The user saw no flashes or duplicate windows.
4. **Ghostty `new window` via AppleScript was rejected.**
   - It would share one process across windows. With `confirm-close-surface = false`, Cmd+Q would then close all terminals without asking.
   - `window-inherit-working-directory = true` changes which folder new windows open in.
   - On a cold start it can create two windows (`initial-window = true`).
5. **Finder: `:focus "Finder"` would be a regression.** `activate` doesn't open a window when Finder has none; `open -a` sends "reopen", which does.
6. **Hyper+d (dark mode).**
   - **Cause:** since Karabiner 16.2.0 (installed 2026-09-07), the helper `org.pqrs.Karabiner-Console-User-Server.app` is responsible for every process Karabiner spawns.
     - It is hardened with no entitlements (upstream `src/apps/ConsoleUserServer/project.yml`: `CODE_SIGN_ENTITLEMENTS: ''`).
     - TCC therefore denies Apple Events to System Events without prompting: the log shows `requires entitlement com.apple.security.automation.apple-events but it is missing`.
     - The user cannot grant this, because no Automation entry is ever created. A `bash -lc` wrapper doesn't help (tested).
   - **What changed:** up to 16.0.0 the helper was a bare tool, `karabiner_console_user_server` (now removed from disk). The spawn code (`pqrs/process`) is functionally unchanged. The binding was added 2026-05-20 under 16.0.0.
   - **Not proven:** that the old tool held an Automation grant. Logs from that period are gone. The user can confirm by checking System Settings > Privacy & Security > Automation for a leftover `karabiner_console_user_server` entry.
   - **The `dark-mode` tool itself is fine,** but has two weaknesses:
     - It discards every AppleScript error (`executeAndReturnError(nil)`), so it always exits 0.
     - Its toggle reads the stored preference, not the visible appearance. With Appearance set to Auto, the first press at night changes nothing visible.
     - It's unmaintained (v3.0.2, 2021).
   - **Fix:** a user-created Shortcut "Toggle Dark Mode" (Set Appearance → Toggle). The user confirmed that Hyper+d works with it.
7. **General rule from finding 6:** any Karabiner `shell_command` that sends Apple Events other than `activate` will silently fail on Karabiner ≥ 16.2.0. Hand such work to another process via `open -a <applet>` or `shortcuts run`. `launch-focus` is unaffected: it only uses `activate` and `is running`, which TCC doesn't block.

## Next steps (proposed, in priority order)
1. **The user commits their own `karabiner.edn` changes.**
   - Committed HEAD still has `:focus`/`:focus_bid` pointing at `/usr/local/bin/launch-focus`, which doesn't exist. The working `$HOME/dotfiles/common-macos/bin/launch-focus` path exists only in the uncommitted working copy.
   - The same working copy also holds the user's Hyper+B borders-ctl rule, the ctrl-tab rule for zen/safari/obsidian/ghostty, and the dia removal.
   - `karabiner.json` (generated, tracked) is also uncommitted.
   - Other staged work (aerospace, sketchybar and yabai-script deletions, borders-ctl) is the user's; don't commit it without asking.
   - Verify: `git show HEAD:common-macos/karabiner/.config/karabiner.edn | grep launch-focus` shows `$HOME/...` paths.
2. **Appearance back to Auto.** The user should set System Settings > Appearance > Auto if dark-mode testing left it fixed. Verify: `defaults read -g AppleInterfaceStyleSwitchesAutomatically` prints `1`.
3. **Optional: `brew uninstall dark-mode`.** No binding or script uses it any more; only archived backup JSONs and `karabiner.json.bak-*` mention it. Ask before uninstalling. Also check any Brewfile the user keeps outside the repo.
4. **Optional: rewrite stale comments.** The user plans to do this themselves:
   - edn line ~61 still says `launch-focus` lives in `/usr/local/bin`.
   - Two commented rules name deleted templates (`launch_focus_front_app_bid`).
5. **Optional, needs a test: replace `launch-focus` with plain templates,** e.g. `:launch "open -a %s"` and `:launch_bid "open -b %s"`.
   - Behavior change for running apps: "reopen" instead of `activate`, which creates or un-minimizes a window when none is visible. That's probably wanted for Arc and VSCode, but verify per app: Arc, Obsidian, Paperless-ngx, Todoist, Calendar, Gmail, Claude, Gemini, VSCode, WhatsApp.
   - Test each with zero windows, minimized windows and normal windows.
   - If kept instead, simplify the script: the poll-then-activate loop is now mostly redundant, since `open` already brings the app forward.
   - Fix the quirk in `[[ -n "$BID" ]] && focus_app ... || focus_app "$APP" "name"`: a failed activate by bundle ID retries by name with an empty name.
   - Any test that opens or focuses windows needs the user's OK first.
6. **Optional: report upstream** at github.com/pqrs-org/Karabiner-Elements/issues. Since 16.2.0, `shell_command` scripts that send Apple Events are blocked without a prompt; include the TCC log line from finding 6. No existing report was found. This is the user's call.
