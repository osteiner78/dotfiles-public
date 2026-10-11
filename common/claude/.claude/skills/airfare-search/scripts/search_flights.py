#!/usr/bin/env python3
"""
Airfare search across Google Flights (via fli) and Kiwi Tequila API.
Outputs a markdown report with the cheapest flights ranked by price.

Usage:
  python3 search_flights.py --origin GVA --dest NRT --depart 2025-03-20 [--return 2025-03-27] \
      [--currency EUR] [--output report.md]
"""

import argparse
import concurrent.futures
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

# ---------------------------------------------------------------------------
# Google Flights via fli
# ---------------------------------------------------------------------------

def search_google_flights(origin: str, dest: str, depart: str, ret: str | None, currency: str) -> list[dict]:
    try:
        from fli.search import SearchFlights
        from fli.models import (
            Airport, FlightSearchFilters, FlightSegment, PassengerInfo,
            SeatType, SortBy, TripType, MaxStops,
        )
    except ImportError:
        print("[google] fli not installed — run: pip install flights", file=sys.stderr)
        return []

    try:
        origin_airport = Airport[origin.upper()]
        dest_airport = Airport[dest.upper()]
    except KeyError as e:
        print(f"[google] Unknown airport code: {e}", file=sys.stderr)
        return []

    trip_type = TripType.ROUND_TRIP if ret else TripType.ONE_WAY
    segments = [
        FlightSegment(
            departure_airport=[[origin_airport, 0]],
            arrival_airport=[[dest_airport, 0]],
            travel_date=depart,
        )
    ]
    if ret:
        segments.append(
            FlightSegment(
                departure_airport=[[dest_airport, 0]],
                arrival_airport=[[origin_airport, 0]],
                travel_date=ret,
            )
        )

    filters = FlightSearchFilters(
        trip_type=trip_type,
        passenger_info=PassengerInfo(adults=1),
        flight_segments=segments,
        seat_type=SeatType.ECONOMY,
        sort_by=SortBy.CHEAPEST,
    )

    try:
        client = SearchFlights()
        raw = client.search(filters, top_n=10, currency=currency)
    except Exception as e:
        print(f"[google] Search failed: {e}", file=sys.stderr)
        return []

    if not raw:
        return []

    results = []
    for item in raw:
        # One-way: FlightResult; Round-trip: tuple[FlightResult, FlightResult]
        if isinstance(item, tuple):
            outbound, ret_leg = item[0], item[1]
            price = (outbound.price or 0) + (ret_leg.price or 0) or None
            all_legs = list(outbound.legs) + list(ret_leg.legs)
            duration = outbound.duration + ret_leg.duration
            stops = outbound.stops + ret_leg.stops
        else:
            outbound = item
            all_legs = list(outbound.legs)
            price = outbound.price
            duration = outbound.duration
            stops = outbound.stops

        if price is None:
            continue

        legs_data = []
        for leg in all_legs:
            airline_code = leg.airline.name if hasattr(leg.airline, 'name') else str(leg.airline)
            legs_data.append({
                "airline": airline_code,
                "flight_number": f"{airline_code}{leg.flight_number}",
                "from": leg.departure_airport.value if hasattr(leg.departure_airport, 'value') else str(leg.departure_airport),
                "from_code": leg.departure_airport.name if hasattr(leg.departure_airport, 'name') else str(leg.departure_airport),
                "to": leg.arrival_airport.value if hasattr(leg.arrival_airport, 'value') else str(leg.arrival_airport),
                "to_code": leg.arrival_airport.name if hasattr(leg.arrival_airport, 'name') else str(leg.arrival_airport),
                "departure": leg.departure_datetime.isoformat() if leg.departure_datetime else None,
                "arrival": leg.arrival_datetime.isoformat() if leg.arrival_datetime else None,
                "duration_min": leg.duration,
            })

        outbound_leg_count = len(outbound.legs) if isinstance(item, tuple) else len(all_legs)
        if ret:
            gf_url = (f"https://www.google.com/travel/flights?hl=en&curr={currency}"
                      f"#flt={origin_airport.name}.{dest_airport.name}.{depart}"
                      f"*{dest_airport.name}.{origin_airport.name}.{ret};c:{currency};e:1;sd:1;t:r")
        else:
            gf_url = (f"https://www.google.com/travel/flights?hl=en&curr={currency}"
                      f"#flt={origin_airport.name}.{dest_airport.name}.{depart};c:{currency};e:1;sd:1;t:f")
        results.append({
            "source": "Google Flights",
            "price": price,
            "currency": currency,
            "duration_min": duration,
            "stops": stops,
            "legs": legs_data,
            "outbound_leg_count": outbound_leg_count,
            "virtual_interlining": False,
            "booking_url": gf_url,
        })

    return results


# ---------------------------------------------------------------------------
# Kiwi Tequila API
# ---------------------------------------------------------------------------

def search_kiwi(origin: str, dest: str, depart: str, ret: str | None, currency: str) -> list[dict]:
    api_key = os.environ.get("KIWI_API_KEY")
    if not api_key:
        print("[kiwi] KIWI_API_KEY not set — skipping", file=sys.stderr)
        return []

    try:
        import requests
    except ImportError:
        print("[kiwi] requests not installed — run: pip install requests", file=sys.stderr)
        return []

    # Kiwi expects dates as DD/MM/YYYY
    def fmt(iso_date: str) -> str:
        d = datetime.strptime(iso_date, "%Y-%m-%d")
        return d.strftime("%d/%m/%Y")

    params: dict = {
        "fly_from": origin.upper(),
        "fly_to": dest.upper(),
        "date_from": fmt(depart),
        "date_to": fmt(depart),
        "adults": 1,
        "selected_cabins": "M",  # Economy
        "curr": currency,
        "limit": 20,
        "sort": "price",
        "asc": 1,
    }
    if ret:
        params["return_from"] = fmt(ret)
        params["return_to"] = fmt(ret)

    try:
        resp = requests.get(
            "https://api.tequila.kiwi.com/v2/search",
            headers={"apikey": api_key},
            params=params,
            timeout=30,
        )
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        print(f"[kiwi] Request failed: {e}", file=sys.stderr)
        return []

    results = []
    for flight in data.get("data", []):
        price = flight.get("price")
        if price is None:
            continue

        legs_data = []
        for leg in flight.get("route", []):
            dep_ts = leg.get("dTime")
            arr_ts = leg.get("aTime")
            dep_dt = datetime.fromtimestamp(dep_ts, tz=timezone.utc).isoformat() if dep_ts else None
            arr_dt = datetime.fromtimestamp(arr_ts, tz=timezone.utc).isoformat() if arr_ts else None
            dur_sec = leg.get("duration")
            legs_data.append({
                "airline": leg.get("airline", ""),
                "flight_number": f"{leg.get('airline', '')}{leg.get('flight_no', '')}",
                "from": leg.get("cityFrom", leg.get("flyFrom", "")),
                "from_code": leg.get("flyFrom", ""),
                "to": leg.get("cityTo", leg.get("flyTo", "")),
                "to_code": leg.get("flyTo", ""),
                "departure": dep_dt,
                "arrival": arr_dt,
                "duration_min": dur_sec // 60 if dur_sec else None,
            })

        total_dur_sec = flight.get("duration", {}).get("total") or flight.get("fly_duration_secs")
        total_dur_min = total_dur_sec // 60 if total_dur_sec else None
        stops = max(0, len(legs_data) - (2 if ret else 1))

        results.append({
            "source": "Kiwi",
            "price": float(price),
            "currency": currency,
            "duration_min": total_dur_min,
            "stops": stops,
            "legs": legs_data,
            "virtual_interlining": flight.get("virtual_interlining", False),
            "booking_url": flight.get("deep_link"),
        })

    return results


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

def fmt_duration(minutes: int | None) -> str:
    if minutes is None:
        return "?"
    h, m = divmod(minutes, 60)
    return f"{h}h{m:02d}m"


def fmt_datetime(iso: str | None) -> str:
    if not iso:
        return "?"
    try:
        dt = datetime.fromisoformat(iso)
        return dt.strftime("%d %b %H:%M")
    except Exception:
        return iso


def stops_label(n: int) -> str:
    if n == 0:
        return "nonstop"
    if n == 1:
        return "1 stop"
    return f"{n} stops"


def legs_summary(legs: list[dict], depart_date: str, ret_date: str | None, outbound_leg_count: int | None = None) -> str:
    if not legs:
        return "_no leg data_"

    # Split legs into outbound / return.
    # Use outbound_leg_count (from fli) when available — immune to overnight-connection date bugs.
    # Fall back to departure-date heuristic for Kiwi results.
    outbound = []
    ret_legs = []
    if ret_date:
        if outbound_leg_count is not None:
            outbound = legs[:outbound_leg_count]
            ret_legs = legs[outbound_leg_count:]
        else:
            ret_prefix = ret_date[:10]
            for leg in legs:
                dep = (leg.get("departure") or "")[:10]
                if ret_legs or dep >= ret_prefix:
                    ret_legs.append(leg)
                else:
                    outbound.append(leg)
        if not outbound:
            outbound = legs
    else:
        outbound = legs

    def render_legs(lgs: list[dict]) -> str:
        lines = []
        for leg in lgs:
            fn = leg.get("flight_number") or leg.get("airline", "")
            fr = leg.get("from_code") or leg.get("from", "")
            to = leg.get("to_code") or leg.get("to", "")
            dep = fmt_datetime(leg.get("departure"))
            arr = fmt_datetime(leg.get("arrival"))
            dur = fmt_duration(leg.get("duration_min"))
            lines.append(f"  - {fn} · {dep} · {fr} → {to} · {arr} ({dur})")
        return "\n".join(lines)

    parts = [f"**Outbound**\n{render_legs(outbound)}"]
    if ret_legs:
        parts.append(f"**Return**\n{render_legs(ret_legs)}")
    return "\n".join(parts)


def generate_report(
    results: list[dict],
    origin: str,
    dest: str,
    depart: str,
    ret: str | None,
    currency: str,
    top_n: int = 5,
) -> str:
    trip = f"{origin.upper()} → {dest.upper()}" + (f" → {origin.upper()}" if ret else "")
    dates = depart + (f" / return {ret}" if ret else "")
    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    lines = [
        f"# Airfare Search: {trip}",
        f"",
        f"**Route:** {trip}  ",
        f"**Dates:** {dates}  ",
        f"**Class:** Economy — 1 passenger  ",
        f"**Generated:** {now}  ",
        f"",
    ]

    if not results:
        lines.append("_No results found from any source._")
        return "\n".join(lines)

    # Deduplicate: same source+airlines+depart time fingerprint
    seen = set()
    unique = []
    for r in results:
        key = (
            r["source"],
            r.get("price"),
            tuple(l.get("flight_number", "") for l in r.get("legs", [])),
        )
        if key not in seen:
            seen.add(key)
            unique.append(r)

    # Sort by price
    unique.sort(key=lambda r: r.get("price") or float("inf"))
    top = unique[:top_n]

    lines.append(f"## Top {len(top)} Cheapest Options")
    lines.append("")
    lines.append(f"| # | Airlines | Price ({currency}) | Stops | Total Duration | Source |")
    lines.append(f"|---|----------|-------------------|-------|----------------|--------|")
    for i, r in enumerate(top, 1):
        price = f"{r['price']:.0f}" if r.get("price") else "?"
        stops = stops_label(r.get("stops") or 0)
        dur = fmt_duration(r.get("duration_min"))
        # Unique airline codes in order (outbound legs only for round trips)
        n_out = r.get("outbound_leg_count") or len(r.get("legs", []))
        out_legs = r.get("legs", [])[:n_out]
        airlines = list(dict.fromkeys(l.get("airline", "") for l in out_legs if l.get("airline")))
        airline_str = " + ".join(airlines) if airlines else "?"
        if r.get("virtual_interlining"):
            airline_str += " ⚠️"
        lines.append(f"| {i} | {airline_str} | {price} | {stops} | {dur} | {r['source']} |")

    lines.append("")
    lines.append("---")
    lines.append("")
    lines.append("## Flight Details")
    lines.append("")

    for i, r in enumerate(top, 1):
        price = f"{r['price']:.0f} {r.get('currency', currency)}" if r.get("price") else "price unknown"
        stops = stops_label(r.get("stops") or 0)
        dur = fmt_duration(r.get("duration_min"))
        vi_note = " _(virtual interlining — separate tickets)_" if r.get("virtual_interlining") else ""
        lines.append(f"### Option {i} — {price} · {stops} · {dur} [{r['source']}]{vi_note}")
        lines.append("")
        lines.append(legs_summary(r.get("legs", []), depart, ret, r.get("outbound_leg_count")))
        if r.get("booking_url"):
            lines.append("")
            label = "Book on Kiwi" if r.get("source") == "Kiwi" else "Search on Google Flights"
            lines.append(f"[{label}]({r['booking_url']})")
        lines.append("")

    # Source summary
    sources_used = sorted({r["source"] for r in unique})
    sources_empty = []
    if "Google Flights" not in sources_used:
        sources_empty.append("Google Flights")
    if "Kiwi" not in sources_used:
        sources_empty.append("Kiwi")

    lines.append("---")
    lines.append("")
    lines.append("## Sources")
    lines.append("")
    for s in sources_used:
        count = sum(1 for r in unique if r["source"] == s)
        lines.append(f"- **{s}**: {count} result(s)")
    for s in sources_empty:
        lines.append(f"- **{s}**: no results (check setup or connectivity)")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Search and compare airfares")
    parser.add_argument("--origin", required=True, help="IATA code, e.g. GVA")
    parser.add_argument("--dest", required=True, help="IATA code, e.g. NRT")
    parser.add_argument("--depart", required=True, help="Departure date YYYY-MM-DD")
    parser.add_argument("--return", dest="ret", default=None, help="Return date YYYY-MM-DD (round trip)")
    parser.add_argument("--currency", default="EUR", help="Currency code (default: EUR)")
    parser.add_argument("--output", default=None, help="Output .md file path (prints to stdout if omitted)")
    parser.add_argument("--top", type=int, default=5, help="Number of top results (default: 5)")
    args = parser.parse_args()

    print(f"[search] {args.origin.upper()} → {args.dest.upper()}, depart {args.depart}" +
          (f", return {args.ret}" if args.ret else " (one-way)") +
          f", currency {args.currency}", file=sys.stderr)

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        gf_future = executor.submit(search_google_flights, args.origin, args.dest, args.depart, args.ret, args.currency)
        kiwi_future = executor.submit(search_kiwi, args.origin, args.dest, args.depart, args.ret, args.currency)
        gf_results = gf_future.result()
        kiwi_results = kiwi_future.result()

    print(f"[search] Google Flights: {len(gf_results)} results", file=sys.stderr)
    print(f"[search] Kiwi: {len(kiwi_results)} results", file=sys.stderr)

    all_results = gf_results + kiwi_results
    report = generate_report(all_results, args.origin, args.dest, args.depart, args.ret, args.currency, top_n=args.top)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(report, encoding="utf-8")
        print(f"[search] Report saved to {out}", file=sys.stderr)
    else:
        print(report)


if __name__ == "__main__":
    main()
