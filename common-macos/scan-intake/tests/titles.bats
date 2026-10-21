#!/usr/bin/env bats
# Phase 7.2 — the title is derived from the file name (ScanSnap prefix removed,
# max 80 characters); the uploaded filename stays scan.<ext>. Names are from
# real scans.

load helpers

post_argv() { grep 'post_document' "$STUB_LOG/curl.log" | tr '\037' '\n'; }

# The title as paperless receives it: the -F value, with curl's optional
# double quotes and \" escapes removed.
sent_title() {
    local raw
    raw="$(post_argv | sed -n 's/^title=//p' | head -n 1)"
    if [[ "$raw" == \"*\" ]]; then
        raw="${raw:1:${#raw}-2}"
        raw="${raw//\\\"/\"}"
    fi
    printf '%s' "$raw"
}

assert_title() { # expected
    local got
    got="$(sent_title)"
    [[ "$got" == "$1" ]] || {
        echo "expected title: $1"
        echo "got title:      $got"
        return 1
    }
}

FALLBACK_RE='^Scan [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}\.[0-9]{2}$'

@test "ScanSnap prefix is dropped and a long name is cut at a word, max 80 characters" {
    make_scan "01011996_Allgemeine Mitteilung (ABC) - Zustellung einer Kopie der aktuellen Vereinbarung zum Beispielvertrag.pdf"
    run_intake --once
    assert_title "Allgemeine Mitteilung (ABC) - Zustellung einer Kopie der aktuellen Vereinbarung"
}

@test "leading '- ' after the prefix is trimmed" {
    make_scan "20102026_- Why was my request delayed? . Depending on the volume of requests, we are not always able to answer within a week and have to ask for patience. We regret that no.pdf"
    run_intake --once
    assert_title "Why was my request delayed? . Depending on the volume of requests, we are not"
}

@test "accents and apostrophes survive" {
    make_scan "20102026_Portail clients Exemple vos données d'accès.pdf"
    run_intake --once
    assert_title "Portail clients Exemple vos données d'accès"
}

@test "runs of whitespace collapse and trailing spaces are trimmed" {
    make_scan "20102026_Foo   Bar .pdf"
    run_intake --once
    assert_title "Foo Bar"
}

@test "pure timestamp name falls back to 'Scan YYYY-MM-DD HH.MM'" {
    make_scan "20261021091350.pdf"
    run_intake --once
    [[ "$(sent_title)" =~ $FALLBACK_RE ]]
}

@test "nothing left after the prefix falls back to 'Scan YYYY-MM-DD HH.MM'" {
    make_scan "12345678_.pdf"
    run_intake --once
    [[ "$(sent_title)" =~ $FALLBACK_RE ]]
}

@test "a name that is not from ScanSnap is used as the title" {
    make_scan "Rechnung.pdf"
    run_intake --once
    assert_title "Rechnung"
}

@test "a date in the title doesn't reach the filename: still filename=scan.pdf" {
    make_scan "30092026_Musterfirma AG Case postale T 000 000 00 00 www.example.ch t i0 8000 Zurich __ I '... Montant CHF 123.45 Date 30.09.2026 Facture n° XX-0000-0000-000 8000 Poste CR SA 000000000000 . . Zurich .pdf"
    run_intake --once
    post_argv | grep -q ';filename=scan\.pdf$'
    [[ "$(sent_title)" == "Musterfirma AG Case postale"* ]]
    ! post_argv | grep -q 'filename=.*30\.09\.2026'
}

@test "a title with ';' is sent quoted, so curl doesn't split it" {
    make_scan "Brief; Mai.pdf"
    run_intake --once
    post_argv | grep -qxF 'title="Brief; Mai"'
}

@test "a title with a double quote arrives intact" {
    make_scan '20102026_Rechnung "Mai".pdf'
    run_intake --once
    assert_title 'Rechnung "Mai"'
}

@test "without LANG the 80-character cut doesn't split a multi-byte character" {
    local stem
    stem="$(printf 'a%.0s' {1..79})ééééé"
    make_scan "12345678_$stem.pdf"
    run env -u LANG -u LC_ALL -u LC_CTYPE "$SCRIPT" --once
    local got
    got="$(sent_title)"
    printf '%s' "$got" | iconv -f UTF-8 -t UTF-8 >/dev/null
    [[ "$got" == "$(printf 'a%.0s' {1..79})é" ]]
}

@test "NON-REGRESSION: a dated name still gets no title" {
    make_scan "2026-01-15 - Test.pdf"
    run_intake --once
    ! post_argv | grep -q '^title='
}

# ── phase 10.1: curl -F reads a file for a value starting with < or @ ───────

@test "a title starting with '<' is sent quoted, so curl doesn't read a file" {
    make_scan "<Kopie> Brief.pdf"
    run_intake --once
    assert_status 0
    post_argv | grep -qxF 'title="<Kopie> Brief"'
    assert_in done "<Kopie> Brief.pdf"
}

@test "a title starting with '@' is sent quoted, so curl doesn't upload a file" {
    make_scan "@home.pdf"
    run_intake --once
    assert_status 0
    post_argv | grep -qxF 'title="@home"'
    assert_in done "@home.pdf"
}

@test "NON-REGRESSION: a '<' that isn't leading doesn't force quoting" {
    make_scan "a <b> c.pdf"
    run_intake --once
    post_argv | grep -qxF 'title=a <b> c'
}
