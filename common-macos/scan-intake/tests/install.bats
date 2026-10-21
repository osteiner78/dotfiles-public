#!/usr/bin/env bats
# Phase 4 — install.sh / uninstall.sh (launchctl is stubbed; $HOME is a temp dir).

load helpers

PLIST_REL="Library/LaunchAgents/xyz.osteiner.scan-intake.plist"
LABEL="xyz.osteiner.scan-intake"

plist_get() { plutil -extract "$1" raw -o - "$HOME/$PLIST_REL"; }

# ── non-regression: these pass before phase 4 and must keep passing ────────

@test "NON-REGRESSION: a .env inside the tool dir is git-ignored" {
    git -C "$ROOT" check-ignore -q "$ROOT/.env"
}

@test "NON-REGRESSION: the repo's stow installer does not stow scan-intake" {
    ! grep -q 'scan-intake' "$ROOT/../../install.sh"
}

# ── first install without a token ───────────────────────────────────────────

@test ".env.example ships with an empty token" {
    grep -qx 'PAPERLESS_TOKEN=' "$ROOT/.env.example"
}

@test "install without .env: copies .env.example to ~/.config/scan-intake/.env with mode 600" {
    rm "$ENV_FILE"
    run "$ROOT/install.sh"
    [[ -f "$ENV_FILE" ]]
    [[ "$(stat -f %Lp "$ENV_FILE")" == 600 ]]
}

@test "install without .env: exits non-zero and tells the user to paste the token" {
    rm "$ENV_FILE"
    run "$ROOT/install.sh"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"API Auth Token"* ]]
}

@test "install without .env: does not load the LaunchAgent" {
    rm "$ENV_FILE"
    run "$ROOT/install.sh"
    [[ -f "$ENV_FILE" ]]
    ! grep -q bootstrap "$STUB_LOG/launchctl.log"
}

@test "install with .env but an empty token: exits non-zero, asks for the token, does not load the agent" {
    sed -i '' 's/^PAPERLESS_TOKEN=.*/PAPERLESS_TOKEN=/' "$ENV_FILE"
    run "$ROOT/install.sh"
    [[ "$status" -ne 0 ]]
    [[ "$output" == *"API Auth Token"* ]]
    ! grep -q bootstrap "$STUB_LOG/launchctl.log"
}

# ── install with a token ────────────────────────────────────────────────────

@test "install: exits 0, creates the scan folders" {
    run "$ROOT/install.sh"
    assert_status 0
    for d in outbox pending done duplicates failed; do
        [[ -d "$SCANS/$d" ]] || { echo "missing $d/"; return 1; }
    done
}

@test "install: renders a valid plist" {
    run "$ROOT/install.sh"
    plutil -lint "$HOME/$PLIST_REL"
}

@test "install: plist has the label, --once, and absolute paths (no ~)" {
    run "$ROOT/install.sh"
    [[ "$(plist_get Label)" == "$LABEL" ]]
    [[ "$(plist_get ProgramArguments.0)" == /* ]]
    [[ "$(plist_get ProgramArguments.1)" == "--once" ]]
    ! grep -q '~' "$HOME/$PLIST_REL"
}

@test "install: plist watches ~/Scans/outbox, runs every 900 s and at load" {
    run "$ROOT/install.sh"
    [[ "$(plist_get WatchPaths.0)" == "$HOME/Scans/outbox" ]]
    [[ "$(plist_get StartInterval)" == 900 ]]
    [[ "$(plist_get RunAtLoad)" == true ]]
}

@test "install: plist sends stdout and stderr to the log and sets PATH" {
    run "$ROOT/install.sh"
    [[ "$(plist_get StandardOutPath)" == "$LOG" ]]
    [[ "$(plist_get StandardErrorPath)" == "$LOG" ]]
    [[ "$(plist_get EnvironmentVariables.PATH)" == "/usr/bin:/bin:/usr/sbin:/opt/homebrew/bin" ]]
}

@test "install: symlinks the script into ~/.local/bin" {
    run "$ROOT/install.sh"
    [[ "$(readlink "$HOME/.local/bin/scan-intake")" == "$ROOT/scan-intake" ]]
}

@test "install: bootstraps the agent into gui/<uid>" {
    run "$ROOT/install.sh"
    grep -q "bootstrap gui/$(id -u) $HOME/$PLIST_REL" "$STUB_LOG/launchctl.log"
}

@test "install: runs the selftest" {
    run "$ROOT/install.sh"
    grep -q 'api/tags/?page_size=1' "$STUB_LOG/curl.log"
}

@test "install twice: second run boots out the old agent before bootstrapping" {
    run "$ROOT/install.sh"
    run "$ROOT/install.sh"
    assert_status 0
    local last_two
    last_two="$(grep -E 'bootout|bootstrap' "$STUB_LOG/launchctl.log" | tail -n 2)"
    [[ "$(head -n 1 <<<"$last_two")" == "bootout gui/$(id -u)/$LABEL" ]]
    [[ "$(tail -n 1 <<<"$last_two")" == bootstrap* ]]
}

# ── uninstall ───────────────────────────────────────────────────────────────

@test "uninstall: boots out the agent and removes the plist" {
    run "$ROOT/install.sh"
    run "$ROOT/uninstall.sh"
    assert_status 0
    grep -q "bootout gui/$(id -u)/$LABEL" "$STUB_LOG/launchctl.log"
    [[ ! -e "$HOME/$PLIST_REL" ]]
}

@test "uninstall: removes the ~/.local/bin symlink" {
    run "$ROOT/install.sh"
    run "$ROOT/uninstall.sh"
    assert_status 0
    [[ ! -L "$HOME/.local/bin/scan-intake" ]]
}

@test "uninstall: leaves ~/Scans and .env alone" {
    run "$ROOT/install.sh"
    [[ -f "$HOME/$PLIST_REL" ]]
    make_scan "keep.pdf"
    run "$ROOT/uninstall.sh"
    assert_in outbox "keep.pdf"
    [[ -f "$ENV_FILE" ]]
}

# ── phase 7.3 ───────────────────────────────────────────────────────────────

@test ".env.example warns that API_VERSION must stay 9" {
    grep -Eq '^#.*API_VERSION.*9' "$ROOT/.env.example"
    grep -qx 'API_VERSION=9' "$ROOT/.env.example"
}

# ── phase 9.3: the weekly health-check agent ────────────────────────────────

HEALTH_LABEL="xyz.osteiner.scan-intake.health"
HEALTH_PLIST_REL="Library/LaunchAgents/$HEALTH_LABEL.plist"

health_get() { plutil -extract "$1" raw -o - "$HOME/$HEALTH_PLIST_REL"; }

@test "the health plist template ships in the repo" {
    [[ -f "$ROOT/scan-intake-health.plist.in" ]]
}

@test "install: renders a valid health plist" {
    run "$ROOT/install.sh"
    assert_status 0
    plutil -lint "$HOME/$HEALTH_PLIST_REL"
}

@test "install: health plist runs '<script> health' with absolute paths (no ~)" {
    run "$ROOT/install.sh"
    [[ "$(health_get Label)" == "$HEALTH_LABEL" ]]
    [[ "$(health_get ProgramArguments.0)" == "$(plist_get ProgramArguments.0)" ]]
    [[ "$(health_get ProgramArguments.1)" == "health" ]]
    ! grep -q '~' "$HOME/$HEALTH_PLIST_REL"
}

@test "install: health plist fires Mondays at 09:00 and not at load" {
    run "$ROOT/install.sh"
    [[ "$(health_get StartCalendarInterval.Weekday)" == 1 ]]
    [[ "$(health_get StartCalendarInterval.Hour)" == 9 ]]
    [[ "$(health_get StartCalendarInterval.Minute)" == 0 ]]
    local ral
    ral="$(health_get RunAtLoad 2>/dev/null || echo absent)"
    [[ "$ral" == absent || "$ral" == false ]]
}

@test "install: health plist logs like the main agent and sets the same PATH" {
    run "$ROOT/install.sh"
    [[ "$(health_get StandardOutPath)" == "$LOG" ]]
    [[ "$(health_get StandardErrorPath)" == "$LOG" ]]
    [[ "$(health_get EnvironmentVariables.PATH)" == "/usr/bin:/bin:/usr/sbin:/opt/homebrew/bin" ]]
}

@test "install: bootstraps the health agent before the main agent" {
    run "$ROOT/install.sh"
    local h m
    h="$(grep -n "bootstrap gui/$(id -u) $HOME/$HEALTH_PLIST_REL" "$STUB_LOG/launchctl.log" | head -n 1 | cut -d: -f1)"
    m="$(grep -n "bootstrap gui/$(id -u) $HOME/$PLIST_REL" "$STUB_LOG/launchctl.log" | head -n 1 | cut -d: -f1)"
    [[ -n "$h" && -n "$m" ]]
    ((h < m))
}

@test "install twice: the health agent is booted out before it is bootstrapped again" {
    run "$ROOT/install.sh"
    : >"$STUB_LOG/launchctl.log"
    run "$ROOT/install.sh"
    assert_status 0
    local out in
    out="$(grep -n "^bootout gui/$(id -u)/$HEALTH_LABEL\$" "$STUB_LOG/launchctl.log" | head -n 1 | cut -d: -f1)"
    in="$(grep -n "bootstrap gui/$(id -u) $HOME/$HEALTH_PLIST_REL" "$STUB_LOG/launchctl.log" | head -n 1 | cut -d: -f1)"
    [[ -n "$out" && -n "$in" ]]
    ((out < in))
}

@test "uninstall: boots out the health agent and removes its plist" {
    run "$ROOT/install.sh"
    run "$ROOT/uninstall.sh"
    assert_status 0
    grep -q "^bootout gui/$(id -u)/$HEALTH_LABEL\$" "$STUB_LOG/launchctl.log"
    [[ ! -e "$HOME/$HEALTH_PLIST_REL" ]]
}

# ── phase 9.4: README ───────────────────────────────────────────────────────

@test "README documents the SwiftBar plugin, terminal-notifier and the health check" {
    grep -qi 'swiftbar' "$ROOT/README.md"
    grep -q 'terminal-notifier' "$ROOT/README.md"
    grep -q 'scan-intake health' "$ROOT/README.md"
}

@test "README lists the new log events" {
    local e
    for e in rejected requeued skipped stale_lock health; do
        grep -q "$e" "$ROOT/README.md" || { echo "README misses $e"; return 1; }
    done
}

# ── phase 10 ────────────────────────────────────────────────────────────────

@test ".env.example no longer offers SCAN_ROOT" {
    ! grep -q 'SCAN_ROOT' "$ROOT/.env.example"
}

@test "README lists the upload_error event" {
    grep -q 'upload_error' "$ROOT/README.md"
}
