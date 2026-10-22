# Experiment: ScanSnap Cloud as a Mac-free intake path

Status: **not started** (planned 2026-10-22, to run later). No code, no tests. The outcome is a
go/no-go decision. Context: the `/plan` discussion of 2026-10-22, and
`docker/paperless-ngx/SCANNER-INTAKE.md` for the server side.

## Why

You want to scan wirelessly without the MacBook. The iX100's Wi-Fi only talks to ScanSnap Home,
the ScanSnap mobile app, or ScanSnap Cloud. SANE supports the iX100 over USB only ("WiFi not
supported"), and nobody has reverse-engineered the Wi-Fi protocol. So ScanSnap Cloud is the only
headless wireless route. Its cons (privacy, depending on the vendor, a new OAuth secret on the
server, less feedback) may outweigh what it gains. This experiment answers the open questions
before any work is planned.

## Questions to answer

| # | Question | Why it matters |
|---|---|---|
| Q1 | What file names does Cloud produce? Is there a date prefix (`YYYY-MM-DD…`)? Can the naming be configured? | Paperless reads `Y-M-D` from file names (`FILENAME_DATE_ORDER`), so the scan date would become the document date. This decides whether a rename step is needed. |
| Q2 | Are the names useful as titles (from OCR), or generic? | scan-intake's titles come from ScanSnap Home's OCR names |
| Q3 | Image quality compared with ScanSnap Home for the same sheet: resolution, colour detection, blank-page removal, deskew, rotation, file size | Whether the server needs to post-process |
| Q4 | Multi-page: how does Cloud group sheets fed one after another into one PDF? Is there a timeout or a button? | The iX100 feeds one sheet at a time |
| Q5 | How long from pressing Scan to the file appearing in the cloud folder? | Usability; sets the polling interval |
| Q6 | With Cloud set up, does Wi-Fi scanning to ScanSnap Home on the Mac still work? Does switching need a setting, a button, or a reconnect? | The Mac path must keep working |
| Q7 | Which destinations are offered for a Swiss account? Can scans go to a dedicated sub-folder? | rclone's access should be limited to that folder |
| Q8 | Which firmware is installed, and was the April 2026 Cloud security update needed? | Whether Cloud works at all |

## Prerequisites

- MacBook with ScanSnap Home (Cloud setup needs a computer once, with the scanner connected).
- A throwaway destination: a new Dropbox app folder or a dedicated Google Drive folder. Not the
  main Drive root.
- **Test sheets with nothing personal on them:** a printed lorem-ipsum page with a date written on
  it, a 2-page printout, a blank-backed sheet, a colour flyer, a crooked sheet. This repo is public
  and the results are written down; real documents must not go through Ricoh for this test.
- 2.4 GHz Wi-Fi in reach (the iX100 doesn't do 5 GHz).

## Steps

1. **Baseline (Mac path).** Scan the test set with ScanSnap Home as today. Note the file names,
   sizes and look, then delete them from paperless and empty the trash (otherwise they block the
   Cloud copies as duplicates; the file bytes differ, but just to be safe).
2. **Firmware (Q8).** In ScanSnap Home, check the iX100's firmware version and update it if
   offered. Note the before and after versions.
3. **Set up Cloud.** Create the ScanSnap account and connect the throwaway destination. Pick one
   folder per document type, or one folder for everything; note what's offered (Q7). Scan
   settings: colour auto, 300 dpi or "Best", blank-page removal on, **searchable PDF off** (the
   server OCRs).
4. **Scan the same test set via Cloud**, with the Mac off or asleep. Time each scan from button
   press to file visible in the cloud web UI (Q5). For the 2-page printout, feed the second sheet
   within a few seconds, then again after about 30 s, and note how many PDFs result (Q4).
5. **Compare (Q1–Q3).** Download the Cloud files. Compare names, page count, resolution
   (`pdfimages -list file.pdf` if poppler is installed, or Preview → Inspector), size and look
   against the baseline.
6. **Paperless dry run (Q1).** Drag one Cloud file into paperless unchanged. Check its created
   date (scan date or the date printed on the page?) and its title. Then delete it and empty the
   trash.
7. **Mac coexistence (Q6).** Wake the Mac and scan with ScanSnap Home over Wi-Fi. Does it still
   work, and what did you have to switch? Also try USB.
8. **Write the results** to `.agent/reports/013-scansnap-cloud-experiment.md` using the template
   below. No real document names or contents.

## Cleanup (whatever the outcome)

- Delete the test files in the destination, **and empty its trash**.
- Delete the scan history in the ScanSnap Cloud app (Ricoh keeps it up to 14 days otherwise).
- If no-go: delete the ScanSnap account, and revoke ScanSnap's access in Dropbox/Google
  (connected apps).
- Delete any test documents left in paperless, and empty the paperless trash.
- Put the scanner back in the mode that works with ScanSnap Home on the Mac, and check with one
  scan through scan-intake (it should show up in the SwiftBar plugin as usual).

## Decision rule

**Go** (write plan 004 for the server side) only if all of these hold:
- Q1: either no date prefix, or the names are predictable enough for a rename step.
- Q3: quality is acceptable without server-side image processing.
- Q5: under about 5 minutes end to end.
- Q6: the Mac path keeps working with at most a simple switch.
- Privacy: after seeing it, you accept Ricoh + the cloud holding scans temporarily.
- And you actually scan away from the Mac often enough to care.

Otherwise **no-go**: write `.agent/decisions/001-no-scansnap-cloud.md` (context, options looked
at, decision, why) and use the ScanSnap iOS app for the rare scans away from the Mac.

## If go: what plan 004 would cover (sketch, not a commitment)

- rclone in a small container (or a systemd timer) next to paperless. It `move`s from the cloud
  folder into a staging folder, with access scoped to that one folder. The OAuth token lives in
  rclone's config on the server, never in this repo.
- A rename step from staging to the NFS consume folder: strip or replace the date prefix (the same
  rule scan-intake uses).
- Leftover files in the cloud or staging folder older than 1 h → ntfy alert (the success path is
  already covered by the post-consume ntfy push).
- Deployment is done by you on the server; the agent has no SSH to CT 206.

## Results template (`.agent/reports/013-scansnap-cloud-experiment.md`)

```markdown
# ScanSnap Cloud experiment — results
Date: YYYY-MM-DD. Firmware: before … / after …. Destination: …

| # | Answer | Notes |
|---|---|---|
| Q1 file names | e.g. `20261101123456.pdf` | configurable? |
| Q2 titles | | |
| Q3 quality vs ScanSnap Home | | dpi, size, blank pages, rotation |
| Q4 multi-page | | |
| Q5 latency | … s (min/max) | |
| Q6 Mac coexistence | | what had to be switched |
| Q7 destinations / folders | | |
| Q8 firmware | | |
| Paperless dry run | created date = …, title = … | |

Cleanup done: [ ] cloud files + trash [ ] scan history [ ] account/OAuth (if no-go)
[ ] paperless test docs + trash [ ] Mac path re-checked

Decision: go / no-go — why:
```

## Handoff notes

- Server intake facts (consume folder over NFS, polling, date and title rules, ntfy):
  `docker/paperless-ngx/SCANNER-INTAKE.md`, `docker/paperless-ngx/docker-compose.yaml:37,60-67`.
- How scan-intake neutralises the ScanSnap date prefix: `upload` sends `filename=scan.pdf` plus a
  `title` from `scan_title`, which strips a leading `YYYYMMDD_` (`common-macos/scan-intake/scan-intake:224-262`).
  Over the consume folder there is no `title` field, so a rename step would have to give the file a
  clean name instead. Profile settings in `common-macos/scan-intake/README.md`
  ("ScanSnap Home profile").
- Sources: SANE fujitsu backend (`doc/descriptions/fujitsu.desc`, iX100 "good", "WiFi not
  supported"); Ricoh ScanSnap Cloud manuals (iX100 scan settings) and FAQ (14-day retention);
  Ricoh notice of 2025-10-22 (Cloud firmware update, deadline 2026-04-08).
