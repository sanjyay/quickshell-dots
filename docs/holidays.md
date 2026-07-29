# Calendar holidays

Rise marks national and regional public holidays in the calendar month grid.
When India is effective, it also marks the recurring second and fourth Saturday
bank-branch closures.
Color-coded rings encircle holiday dates while preserving the existing today
and selected-date treatments. Multiple holiday classes use concentric rings.
Hovering or selecting a marked date shows every holiday, its textual scope,
country, and region where applicable.

## Configuration

Holiday defaults live in the existing Rise `bar` settings in
`~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "id": "io.github.sanjyay.quickshell-rise",
    "calendar": {
      "holidays": {
        "enabled": true,
        "countryMode": "manual",
        "country": "IN",
        "subdivision": "TN",
        "showNational": true,
        "showRegional": true,
        "showInGrid": true
      }
    }
  }
}
```

`countryMode` is `auto` or `manual`. A manual `country` uses an ISO 3166-1
alpha-2 code. `subdivision` uses the installed `date-holidays` code. The older
form with `country: "auto"` remains compatible. Existing users default to
national and regional holidays enabled. The former generic `showBank` setting
is obsolete and safely ignored when found in older state.

Set `enabled` to `false` to disable all helper work. Set `showInGrid` to
`false` to hide markers. Restart `omarchy-shell` after manually changing nested
bar configuration if the host does not hot-reload it.

## In-calendar settings

Open the calendar and click the small settings icon beside the next-month
button. The month grid becomes a compact **Holiday Region** page:

- Open **Country**, search by dataset name or two-letter code, and choose any
  supported country. **Use system timezone** returns to automatic mode.
- Open **State / Province / Region** and choose a dataset-supported region, or
  choose **National holidays only**. This control is disabled for countries
  without subdivision data.
- Toggle **National public holidays** and **State / regional public holidays**
  independently. Selecting a region automatically enables regional holidays;
  the toggle may be disabled manually afterward.
- When India is active, a note explains that second and fourth Saturday bank
  closures are shown automatically. They are not a configurable dataset
  holiday category.

Country and region names come from the installed dataset rather than a
handwritten list. Typing filters both lists; the country list also supports
Up, Down, and Enter. Selecting another country clears an incompatible region.
Manual country selection remains active across timezone changes until **Use
system timezone** is explicitly selected.

To select Tamil Nadu, choose India, open **State / Province / Region**, search
for Tamil Nadu, and select `TN`. The active year reloads immediately. Tamil
Nadu 2026 uses the bundled official State Government list because
`date-holidays@3.34.0` contains only Labour Day for that subdivision. July 2026
has no Tamil Nadu public holiday, so no regional ring is expected that month.

Selections are atomically persisted across shell restarts at:

```text
${XDG_STATE_HOME:-~/.local/state}/quickshell-rise/holiday-settings.json
```

Delete this file to reset the selector to the configured defaults. Invalid
saved codes produce an actionable warning and are never sent to the generator.
Settings schema 1 is migrated once to schema 2: an existing valid subdivision
enables regional display, obsolete `showBank` is ignored, and subsequent
explicit regional-toggle choices are preserved.

## Country detection

Automatic mode finds an IANA timezone from `TZ`, `/etc/timezone`,
`timedatectl`, or `/etc/localtime`, in that order, then maps it with the system
tzdata `zone1970.tab` or `zone.tab`. It never uses IP geolocation. A
multi-country zone may be disambiguated by `LC_ALL`, `LC_MESSAGES`, or `LANG`;
otherwise the UI requests a manual country. Detection never infers a region.

## Regional providers and classification

Regional data is selected in this order:

1. A validated bundled official file for the selected country, subdivision,
   and year.
2. The installed `date-holidays` subdivision data when no official file exists.
3. Country-level `date-holidays` records for national holidays.

The normalized QML model is provider-independent. Records retain a source
identifier for diagnostics. Equivalent official and country-level holidays are
deduplicated by normalized date and name, while genuinely distinct names on
one date remain visible. Country-wide records such as Republic Day remain
national. Tamil Nadu statewide records such as Pongal remain regional.

Tamil Nadu 2026 is sourced from Tamil Nadu Government Gazette Extraordinary
No. 721, Part II—Section 1, G.O.(Ms.) No.708 dated 11 November 2025. Its
annexure contains 24 entries. Rise bundles the 23 statewide public holidays;
the 1 April annual account closing is excluded because the Gazette explicitly
limits it to commercial and co-operative banks.

When a later annual Tamil Nadu order is not yet available, Rise continues using
`date-holidays` and adds only the narrowly verified fixed-date fallback in
`data/holidays/IN/TN/recurring.json`. Currently this supplies New Year's Day,
which appears in consecutive official 2025 and 2026 Tamil Nadu orders. The
provider reports `date-holidays+recurring-fallback` so diagnostics do not imply
that a complete official annual list exists. Movable festivals are never
guessed from an earlier year.

## Indian Saturday bank closures

When the effective country is `IN`, Rise locally calculates the second and
fourth Saturday of every displayed month. It does not use `date-holidays` for
these records and does not make a network request. The first, third, and fifth
Saturdays are not marked. The calculation finds the first Saturday from the
month’s actual weekday and adds 7 and 21 days, so leap years, Saturday-first
months, five-Saturday months, and year boundaries work without fixed dates or
UTC conversion.

The vibrant green ring means “Banks closed” and details say “Second Saturday”
or “Fourth Saturday” plus the India-wide recurring branch-closure rule.
National holidays use a vivid accent-colored ring and regional holidays use a
vivid yellow ring. The hues come from the active theme, with saturation and
brightness raised for calendar readability. Multiple rings can coexist on the
same date. The closure ring is not shown for other countries. Online banking
and individual branch, service, exchange, or payment-system availability are
outside this marker’s scope.

## Offline data and cache

The installer uses npm once to install pinned `date-holidays` data inside the
plugin. Runtime calendar use makes no network requests. Country metadata,
subdivision metadata, and holiday results are cached at:

```text
${XDG_CACHE_HOME:-~/.cache}/quickshell-rise/holidays/
```

Holiday keys include country, subdivision, year, enabled public scopes,
provider identifier, official-file schema/revision, and dataset version where
applicable. Metadata keys include the dataset version. Cache schema 5
invalidates older incomplete Tamil Nadu results and the earlier 2027 fallback
cache. Cache writes use a temporary
file and atomic rename; malformed entries regenerate. Delete the `holidays`
directory to regenerate everything.

Inspect the active provider and source metadata with:

```bash
omarchy-shell quickshell-rise-health holidayDiagnostics
```

## Verified annual update

The installer enables
`quickshell-rise-holiday-annual-update.timer`. At 09:00 local time every
January 1 (with up to 30 minutes of randomized delay), it checks the trusted
project repository for that year's reviewed `IN/TN` JSON. `Persistent=true`
causes a missed check to run after the machine next starts.

This is deliberately separate from calendar runtime. The updater downloads
only the year-specific JSON over HTTPS, enforces a 1 MiB limit and timeout,
validates the country, subdivision, year, ISO dates, official-source metadata,
duplicates, and record types, then writes atomically to:

```text
${XDG_DATA_HOME:-~/.local/share}/quickshell-rise/holidays/IN/TN/<year>.json
```

It invalidates only matching year caches and restarts `omarchy-shell` after a
successful install. If no reviewed file has been published, existing data is
left untouched, the conservative recurring fallback remains active, and a
desktop notification explains the result. It never scrapes a PDF, copies
search results, or treats an unverified festival date as official.

Check or trigger it manually with:

```bash
systemctl --user list-timers quickshell-rise-holiday-annual-update.timer
systemctl --user start quickshell-rise-holiday-annual-update.service
journalctl --user -u quickshell-rise-holiday-annual-update.service
cat "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-rise/holiday-annual-update.json"
```

The annual state file reports `updated`, `not-published`, or `error`. The
network is used only by this explicit annual updater, never while opening or
navigating the calendar.

### Publishing a future official regional year

The trusted repository still needs a maintainer to verify the complete list
against the original government Gazette or order before January 1. Prepare a
file matching `data/holidays/IN/TN/2026.json`, then validate and normalize it:

```bash
node scripts/import-regional-holidays.js \
  --country IN \
  --subdivision TN \
  --year 2027 \
  --input /path/to/verified-2027.json \
  > data/holidays/IN/TN/2027.json
```

The importer validates codes, year, ISO dates, non-empty names, ordering,
duplicates, and official source metadata. Review its output and citation,
commit it to the project release, and publish it before the timer runs. It
never scrapes or downloads a PDF.

## Troubleshooting

- **Automatic — unresolved** means timezone mapping was ambiguous or
  unavailable. Select a country manually.
- If regional holidays are missing, confirm the selected region, enable
  **State / regional public holidays**, navigate to a month that actually has a
  subdivision record, inspect the active provider, and clear the holiday cache
  if it predates the current helper schema. July 2026 intentionally has no
  Tamil Nadu regional record.
- For a future year whose annual Tamil Nadu order is not yet published,
  diagnostics show `date-holidays+recurring-fallback`. Only verified recurring
  dates are added; the full state list becomes available after a verified
  annual file is published. Check the annual updater state and run its service
  manually after the project publishes the file.
- Indian Saturday closure markers require India to be the effective country.
  Switching to Japan or another country removes them.
- An unsupported saved country or region is shown as a warning. Select a valid
  replacement or reset the state file.
- If Node.js or npm is unavailable, install the distribution `nodejs` and `npm`
  packages and rerun the installer.
- If `zone1970.tab` is unavailable, repair the system `tzdata` package or use a
  manual country.
- Inspect helper output directly with:

  ```bash
  node scripts/holiday-helper.js countries
  node scripts/holiday-helper.js subdivisions IN
  node scripts/holiday-helper.js holidays IN 2026 TN \
    --show-national true --show-regional true
  ```

JSON is written only to stdout; diagnostics use stderr.

## Data source and license

Holiday calculations and data come from
[`date-holidays`](https://github.com/commenthol/date-holidays), pinned in
`package-lock.json`. npm metadata declares `(ISC AND CC-BY-3.0)`; the bundled
`LICENSE` more specifically licenses code under ISC and holiday data under CC
BY-SA 3.0. Rise follows the stricter data notice. The installed package
includes its complete license and source attributions. Rise remains MIT.

Tamil Nadu 2026 regional dates come from the
[Tamil Nadu Government Gazette Extraordinary No. 721](https://stationeryprinting.tn.gov.in/extraordinary/2025/721_Ex_II_1_2025.pdf),
published by the Government of Tamil Nadu on 11 November 2025.

## Limitations

1. A timezone is not the same thing as a country.
2. Some timezones cover multiple countries, so automatic detection can be
   ambiguous.
3. Automatic timezone detection suggests a country only. It cannot determine
   a state, province, physical location, or nationality.
4. The user must select a subdivision manually.
5. An inaccurate or manually configured system timezone may suggest the wrong
   country.
6. Fixed-offset timezones cannot normally be mapped reliably.
7. Not all countries or years have bundled official regional data; those
   selections fall back to `date-holidays`.
8. `date-holidays` subdivision coverage and accuracy vary. Its pinned Tamil
   Nadu rules are incomplete, which is why 2026 has an official override.
9. National-versus-regional classification depends on comparing country and
    subdivision datasets because explicit scope metadata is not dependable for
    every record.
10. Identical normalized dates, names, types, and substitute status at multiple
    jurisdiction levels may not expose enough metadata to identify legal scope
    perfectly.
11. Local, municipal, school, exchange, company, and institution-specific
    closures are outside this feature’s scope.
12. Community-maintained offline data may lag official announcements,
    proclamations, lunar observations, or administrative changes.
13. Official regional files are annual. The January 1 updater can install a
    reviewed file without a full plugin update, but only after a maintainer has
    verified and published it. Plugin updates remain necessary for updater,
    fallback, or schema changes.
14. Before an annual Tamil Nadu order is published, the recurring fallback is
    intentionally incomplete. It marks only fixed dates supported by
    consecutive official orders and does not predict movable festivals.
15. The feature is not authoritative for payroll, legal, banking, school,
    trading, or compliance decisions.
16. The India Saturday marker describes the recurring branch holiday rule; it
    does not guarantee every bank, online service, exchange, branch, or payment
    system is unavailable.
17. Country, subdivision, holiday names, and translations depend on dataset
    coverage.
18. Manual country selection overrides timezone detection until automatic mode
    is explicitly restored.
19. The implementation does not use live government APIs and does not
    guarantee official or legal accuracy.
20. The annual download is protected by HTTPS and strict content validation,
    but is not cryptographically signed separately from the trusted project
    repository.
21. If no reviewed file is available on January 1, Rise does not retry
    automatically during the year; use the documented manual service command
    after publication.
