You are analyzing my focus data from **Auto-Focus**, a macOS app that detects when I work in
my chosen "focus apps" or on "focus websites". Once I've stayed there past a threshold, it
turns on Do Not Disturb and records a focus session. Help me understand my focus patterns and
give me concrete advice.

## Rules

- The data is a SQLite database. Open it **read-only** with `sqlite3 -readonly`. Never write,
  vacuum, or copy over it, because Auto-Focus has it open.
- **Aggregate in SQL.** The event table can hold hundreds of thousands of rows. Never dump raw
  rows; always `GROUP BY` and `LIMIT`.
- **Privacy:** never select the `url` column. For browser events (`eventType = 'tab_changed'`),
  `appName` holds the **page title**, so don't select it for those rows. Group by `domain`
  instead.
- All timestamps are **seconds since 2001-01-01 UTC** (Apple reference date), not Unix time.
  Convert with `datetime(ts + 978307200, 'unixepoch', 'localtime')` and always use
  `'localtime'` for time-of-day analysis.

## Step 1: Find the database and check the schema

Try these paths in order and use the first one that exists:

1. `~/Library/Application Support/auto-focus.auto-focus/autofocus.sqlite`
2. `~/Library/Containers/auto-focus.auto-focus/Data/Library/Application Support/auto-focus.auto-focus/autofocus.sqlite` (older versions)

Run `.schema` and check that it matches the description below. If it doesn't, trust the real
schema and tell me what differs. Then report how many sessions and events there are and the
date range of each table. **The activity log often starts later than the session history**
(older app versions didn't record it). Analyze per-app and per-site questions only over the
period both tables cover, and say which period that is.

## Schema

- `focusSession(id, startTime, endTime)`: one row per completed focus session. `startTime` is
  when I started working in a focus app or site. A session is saved only once I pass the
  focus threshold. I may have changed the threshold over time, so older sessions can be
  shorter than today's threshold. `endTime` is when focus ended, after any buffer period.
- `appEvent(id, bundleIdentifier, appName, timestamp, eventType, domain, url)`: an activity log.
  - `eventType = 'activate'`: I switched to the app `bundleIdentifier` / `appName`.
  - `eventType = 'tab_changed'`: the active browser tab changed. `bundleIdentifier` is the
    browser and `domain` is the website.
  - Bundles `com.apple.loginwindow` and `com.apple.ScreenSaver.Engine` (any `eventType`,
    including `'away'`) mean the screen was locked or asleep. Treat them as "away" and exclude
    them from app rankings.
  - Bundle `auto-focus.auto-focus` is Auto-Focus itself (opening its settings window).
    Exclude it from rankings too.
  - **Browsers log both kinds of event.** The browser's `'activate'` row is followed by
    `'tab_changed'` rows for the sites. Browser `'activate'` time means "browser, site not
    detected", so don't rank the browser as if it were an app I focused in. Treat it as
    *unknown*, neither focus nor non-focus. If it's a large share of my time, tell me site
    tracking may be off for that browser (Automation permission in System Settings, or the
    browser not enabled in Auto-Focus). Browsers are the bundle IDs that have any
    `tab_changed` rows.
- `focusApp(name, bundleIdentifier)`: the apps I marked as focus apps.
- `focusURL(name, domain, matchType, isEnabled, category)`: the websites I marked as focus
  sites. There may be duplicate rows, so deduplicate by `domain`, and strip a leading `*.` from
  wildcard domains. A site counts as a focus site if its domain equals a focus domain or is a
  subdomain of one. Only rows with `isEnabled = 1` are active.
- `setting(key, value)`: values are stored as text, so use `CAST(value AS REAL)`.
  `focusThreshold` is in **minutes** and is how long until a session starts. `focusLossBuffer`
  is in **seconds** and is the grace period after leaving focus. Ignore the other keys.
- Weekdays: `strftime('%w', ...)` returns `0` for Sunday. Use Monday-based weeks
  (`strftime('%Y-W%W', ...)`).
- SQLite has no `MEDIAN`. Use `ORDER BY ... LIMIT 1 OFFSET (COUNT(*) / 2)` or a window function.

## Measuring time per app or site

An event lasts from its timestamp until the next event, capped at 2 hours so a forgotten window
overnight doesn't count. The app's top-apps and top-sites lists use the same rule. Label
every event like this:

```sql
WITH browsers AS (SELECT DISTINCT bundleIdentifier FROM appEvent WHERE eventType = 'tab_changed'),
ev AS (
  SELECT bundleIdentifier, eventType,
    CASE WHEN eventType = 'tab_changed' THEN COALESCE(domain, '(unknown site)')
         WHEN bundleIdentifier IN (SELECT bundleIdentifier FROM browsers)
           THEN COALESCE(appName, bundleIdentifier) || ' (site not detected)'
         ELSE COALESCE(appName, bundleIdentifier) END AS label,
    timestamp AS t0,
    MIN(LEAD(timestamp) OVER (ORDER BY timestamp), timestamp + 7200) AS t1
  FROM appEvent
  WHERE timestamp >= strftime('%s', 'now', '-91 days') - 978307200  -- one extra day of events
)
```

For **time inside focus sessions**, clip each event to the session window. Don't just tag
events by their start time: that over-counts, because an event can start before a session or
run past its end:

```sql
SELECT label, ROUND(SUM(MIN(ev.t1, s.endTime) - MAX(ev.t0, s.startTime)) / 3600.0, 2) AS focus_hours
FROM focusSession s
JOIN ev ON ev.t0 < s.endTime AND ev.t1 > s.startTime
WHERE s.startTime >= strftime('%s', 'now', '-90 days') - 978307200
  AND ev.bundleIdentifier NOT IN ('com.apple.loginwindow', 'com.apple.ScreenSaver.Engine',
                                  'auto-focus.auto-focus')
GROUP BY label ORDER BY focus_hours DESC LIMIT 15;
```

As a check, the clipped hours summed over all labels (with no exclusions) can't exceed
the total session hours for the same window. They should be close when the activity log covers
the whole window, and lower for periods before the log started.

For time **outside** sessions, take each label's total time, `SUM(t1 - t0)`, and subtract its
in-session time.

## What I want to know

Look at all my data, but put the most weight on the **last 90 days**. Compare the last 30
days with the 30 days before that where it's useful.

1. **Overview:** total focus hours; number of sessions; average and median session length;
   sessions per active day; my current threshold and buffer settings.
2. **When I focus best:** focus hours and average session length by hour of day and by
   weekday. Name my best 2–3 time windows and my weakest ones.
3. **Session depth:** session length distribution (for example under 15 min, 15–30, 30–60,
   1–2 h, 2 h+). My 5 longest sessions: when they happened and what I worked in during them.
4. **What powers my focus:** the apps and sites I spend the most time on **inside** sessions,
   compared with outside them. Point out any focus apps or sites I've configured but barely
   use, and any apps or sites I use a lot in sessions that aren't configured.
5. **What breaks my focus:** for each session, the last app or site I switched to before it
   ended (the latest event between `startTime` and `endTime`). Count sessions with no event
   inside them as "(no switch recorded)". Rank them. Also show how much clipped session time
   went to things that are neither focus apps nor focus sites, such as chat or email during
   the buffer.
6. **Fragmentation:** switches per focused hour, counting both `activate` and `tab_changed`
   events inside sessions (report the two separately too), and whether sessions with fewer
   switches last longer. Don't assume more switching is bad. Report what the data shows.
7. **Trend:** weekly focus hours over time. Am I improving, steady, or slipping? Mark the
   current week as partial, and keep in mind that holidays or time off show up as dips.

## Output

- Start with a **3–5 bullet TL;DR**.
- Then one short section per question above. Use small tables and include the actual
  numbers.
- End with **3 specific, actionable recommendations** based on my data. Examples: protect a
  particular time window, mute a specific app that keeps breaking sessions, add a site I
  clearly focus on as a focus URL, or adjust the threshold or buffer, with a reason for each.
- Don't moralize. If the data is too thin for a conclusion, say so.
- Afterwards, offer follow-ups: drill into a specific week, compare two months, or make a
  chart.
