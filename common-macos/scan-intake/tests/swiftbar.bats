#!/usr/bin/env bats
# Phase 9.1 — the SwiftBar plugin. It renders `scan-intake status --json`
# through ~/.local/bin/scan-intake (symlinked to the repo script in the temp
# $HOME), so the curl and launchctl stubs still apply.

load helpers

PLUGIN="$BATS_TEST_DIRNAME/../../swiftbar/.config/swiftbar/scan-intake.1m.sh"

install_link() {
    mkdir -p "$HOME/.local/bin"
    ln -sfn "$SCRIPT" "$HOME/.local/bin/scan-intake"
}

render() {
    run "$PLUGIN"
}

bar_line() { head -n 1 <<<"$output"; }
bar_title() { bar_line | sed 's/|.*//'; }      # the text shown in the menu bar
dropdown() { sed '1,/^---$/d' <<<"$output"; }  # everything below the first ---

# SwiftBar 2.1.1 ignores sfcolor on the menu-bar icon; only an sfconfig with
# Palette rendering colours it (checked live, 2026-10-22). base64 -D is BSD.
bar_is_red() {
    local cfg
    cfg="$(bar_line | tr ' ' '\n' | sed -n 's/^sfconfig=//p')"
    [[ -n "$cfg" ]] || return 1
    base64 -D <<<"$cfg" | jq -e '.renderingMode == "Palette" and ((.colors // []) | index("red") != null)' >/dev/null
}

put() { # subdir name [content]
    mkdir -p "$SCANS/$1"
    printf '%s\n' "${3:-%PDF-1.4}" >"$SCANS/$1/$2"
}

@test "plugin exists, is executable and has an xbar.title header" {
    [[ -x "$PLUGIN" ]]
    grep -q '<xbar.title>' "$PLUGIN"
}

@test "empty state: exit 0, SF Symbol icon, no count, not red" {
    install_link
    render
    assert_status 0
    [[ "$(bar_line)" == *"sfimage=doc.viewfinder"* ]]
    [[ ! "$(bar_title)" =~ [0-9] ]]
    ! bar_is_red
}

@test "outbox + pending count is shown in the menu bar" {
    install_link
    put outbox a.pdf
    put outbox b.pdf
    put pending slow.pdf
    put pending slow.pdf.task "b1ad602d-0000-4000-8000-000000000001"
    render
    [[ "$(bar_title)" =~ (^|[^0-9])3([^0-9]|$) ]]
}

@test "a failed file turns the icon red" {
    install_link
    put failed x.pdf
    put failed x.pdf.error "HTTP 500"
    render
    bar_is_red
}

@test "config error: red, and the reason is the first dropdown line" {
    install_link
    chmod 644 "$ENV_FILE"
    render
    assert_status 0
    bar_is_red
    [[ "$(dropdown | head -n 1)" == *"chmod 600"* ]]
}

@test "agent not loaded: red, and the dropdown says so" {
    install_link
    touch "$FIXTURES/launchctl.fail"
    render
    bar_is_red
    dropdown | grep -qi 'not loaded'
}

@test "each failed file is listed in a submenu with its error" {
    install_link
    put failed x.pdf
    put failed x.pdf.error "Corrupt PDF"
    render
    dropdown | grep -E '^--' | grep -q 'x.pdf'
    dropdown | grep -q 'Corrupt PDF'
}

@test "each failed file has a Retry action calling scan-intake retry <file>" {
    install_link
    put failed x.pdf
    put failed x.pdf.error "HTTP 500"
    render
    local line
    line="$(dropdown | grep 'param1=retry' | grep 'x.pdf')"
    [[ -n "$line" ]]
    [[ "$line" =~ bash=\"?$HOME/.local/bin/scan-intake\"?( |$) ]]
    [[ "$line" == *"terminal=false"* ]]
    [[ "$line" == *"refresh=true"* ]]
}

@test "Retry handles a file name with spaces (quoted param)" {
    install_link
    put failed "Rechnung Mai.pdf"
    put failed "Rechnung Mai.pdf.error" "HTTP 500"
    render
    dropdown | grep 'param1=retry' | grep -qF 'param2="Rechnung Mai.pdf"'
}

@test "Retry all failed calls scan-intake retry all" {
    install_link
    put failed x.pdf
    put failed x.pdf.error "HTTP 500"
    render
    dropdown | grep 'param1=retry' | grep -Eq 'param2="?all"?( |$)'
}

@test "Run now kickstarts the main agent through launchctl" {
    install_link
    render
    local line
    line="$(dropdown | grep 'param1=kickstart')"
    [[ "$line" =~ bash=\"?[^\ ]*launchctl\"? ]]
    [[ "$line" == *"gui/$(id -u)/xyz.osteiner.scan-intake"* ]]
}

@test "Run selftest opens in a terminal" {
    install_link
    render
    local line
    line="$(dropdown | grep 'param1=--selftest')"
    [[ -n "$line" ]]
    [[ "$line" == *"terminal=true"* ]]
}

@test "last upload links to the document in paperless" {
    install_link
    write_success_log
    render
    local line
    line="$(dropdown | grep '#6342')"
    [[ "$line" == *"Portail clients.pdf"* ]]
    [[ "$line" == *"href=https://$PUBLIC_HOST/documents/6342/details"* ]]
}

@test "no log: no last-upload link" {
    install_link
    render
    assert_status 0
    ! dropdown | grep -q 'documents/[0-9]*/details'
}

@test "Open entries cover the Scans folder, failed/, the log and paperless" {
    install_link
    render
    dropdown | grep -qF "$SCANS"
    dropdown | grep -qF "$SCANS/failed"
    dropdown | grep -qF "$LOG"
    dropdown | grep -qE "href=https://$PUBLIC_HOST/?( |$)"
}

@test "scan-intake not installed: one 'not installed' line, exit 0" {
    render
    assert_status 0
    grep -qi 'not installed' <<<"$output"
}

@test "rendering makes no network calls and moves nothing" {
    install_link
    put outbox a.pdf
    put failed x.pdf
    put failed x.pdf.error "HTTP 500"
    render
    assert_status 0
    [[ ! -s "$STUB_LOG/curl.log" ]]
    assert_in outbox a.pdf
    assert_in failed x.pdf
}

@test "status --json failing: red icon and a 'status failed' line" {
    mkdir -p "$HOME/.local/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' >"$HOME/.local/bin/scan-intake"
    chmod +x "$HOME/.local/bin/scan-intake"
    render
    assert_status 0
    bar_is_red
    dropdown | grep -q 'status failed'
}
