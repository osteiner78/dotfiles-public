---
name: airfare-search
description: >
  Fetches LIVE, real-time flight prices that Claude cannot provide from training data alone.
  Use this skill whenever the user needs actual current airfare — finding cheap flights,
  comparing prices across dates or days of week, checking if direct routes exist and what
  they cost, or budgeting for a trip that requires real prices. Trigger even for casual or
  indirect phrasing: "check what flights look like", "figure out the flight budget",
  "what would it cost to fly to X", "find me something cheap to Tokyo". Do NOT trigger for
  general travel advice, visa requirements, airline policies, hotel searches, flight delay
  compensation, loyalty miles, or when the user already has prices and just wants a
  recommendation. Searches Google Flights (fli) and optionally Kiwi.com; always economy,
  1 passenger; saves a ranked markdown report to .agent/reports/.
---

# Airfare Search

Search Google Flights (via the `fli` Python library) and Kiwi.com (Tequila API) in parallel,
combine and rank results by price, and produce a saved markdown report.

---

## Step 1: Clarify the search parameters

Before running anything, make sure you have all four required pieces:

1. **Origin** — city or airport (you need the IATA code, e.g. `GVA` for Geneva)
2. **Destination** — city or airport (IATA code)
3. **Departure date** — exact date (`YYYY-MM-DD`)
4. **Trip type** — one-way or round trip; if round trip, the **return date**

If the user gave a city name but not a code, look it up yourself (e.g. "Zurich" → `ZRH`,
"Tokyo" → usually `NRT` or `HND` — ask which airport if it's ambiguous and the user
hasn't specified). Don't ask for things the user has already given.

Also ask: preferred currency? Default to `EUR` if not specified.

---

## Step 2: Check dependencies

Ensure the `flights` package is installed:

```bash
pip install flights requests --quiet
```

Check whether `KIWI_API_KEY` is set in the environment. If it isn't, tell the user:

> Kiwi.com results require a free API key from tequila.kiwi.com. Set it as
> `export KIWI_API_KEY=your_key` to enable that source. Without it, only
> Google Flights results will appear.

Don't block the search — proceed with whatever sources are available.

---

## Step 3: Determine the output file path

Next available report number in `.agent/reports/`:
```bash
ls .agent/reports/ 2>/dev/null | grep -E '^[0-9]{3}-' | sort | tail -1
```
Use the next sequential number (001 if none exist). Name the file:
`NNN-flights-ORIG-DEST-YYYYMMDD.md` (e.g. `003-flights-GVA-NRT-20250320.md`)

---

## Step 4: Run the search

```bash
python3 ~/.claude/skills/airfare-search/scripts/search_flights.py \
  --origin ORIG \
  --dest DEST \
  --depart YYYY-MM-DD \
  [--return YYYY-MM-DD] \
  --currency EUR \
  --output .agent/reports/NNN-flights-ORIG-DEST-YYYYMMDD.md
```

This runs Google Flights and Kiwi searches in parallel (~20–40 seconds), writes the
report, and prints progress to stderr.

---

## Step 5: Present the results

After the script finishes, read the report and present a brief inline summary:

- The 3 cheapest options (price, stops, total duration, source)
- Whether any virtual interlining options appeared (Kiwi only — these are separate tickets
  with a lower price but higher missed-connection risk)
- Which sources returned results (warn if either source had zero results)

Then tell the user where the full report is saved.

Example summary format:
```
Found 12 results (8 Google Flights, 4 Kiwi).

Cheapest 3:
1. 620 EUR — 1 stop — 14h20m [Google Flights] — LH + LH via FRA
2. 598 EUR — 2 stops — 18h40m [Kiwi] ⚠️ virtual interlining
3. 645 EUR — nonstop — 12h05m [Google Flights] — LX direct

Full report: .agent/reports/003-flights-GVA-NRT-20250320.md
```

### When zero results are returned

If the search returns no results, diagnose which reason applies and respond accordingly:

**1. Date is more than ~11 months in the future**
Airlines don't publish schedules that far ahead, so Google Flights has no inventory.
Do this:
- Tell the user the date is beyond the booking window
- Run a proxy search for the same route on the equivalent date this year (e.g. if they asked for 2027-08-15, try 2026-08-15)
- Include the proxy results in the report, clearly labeled: "Proxy results (2026-08-15) — for price reference only, actual 2027 fares not yet available"
- Add a note: "Set a Google Flights price alert for when fares open, typically 6-10 months before departure"

**2. Rate-limited by Google (HTTP 429)**
- Tell the user to try again in a few minutes

**3. Route genuinely has no service on that date**
- Confirm by trying adjacent dates; if still nothing, say so directly

---

## Notes for future improvements (don't implement now)

- Multiple passengers
- Prices with extra luggage
- Nearby airports (e.g. ZRH + GVA for departures near Geneva)
- Date flexibility (±N days around a target date)
- Open-ended period search ("cheapest day in March")
