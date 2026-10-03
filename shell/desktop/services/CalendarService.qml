pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

// Read-only calendar feed built from .ics files in a local directory.
//
// Deliberately not a CalDAV client. The source is a plain directory of iCalendar
// files, which keeps parsing and the card's data shape independent of whichever
// sync mechanism eventually fills that directory -- vdirsyncer, khard, a
// Thunderbird profile, or files dropped in by hand all produce the same thing.
//
// Nothing is written back. The card is an agenda view, not an editor.
//
// Files are read with Process rather than FileView. FileView cannot enumerate a
// directory, so it would need one instance per file created from a delegate, and
// a FileView in an Instantiator delegate never fired onLoaded here despite being
// handed a valid path -- the scan reported the file as found while the card stayed
// empty. Reading through a shell loop sidesteps that entirely, and comparing
// mtimes gives change detection that FileView's watchChanges would have provided.
Singleton {
    id: root

    // =========================================================================
    // Public Interface
    // =========================================================================

    // Where the .ics files live. XDG_DATA_HOME/calendar is where vdirsyncer and
    // khard put their collections by default, so a synced setup needs no config.
    readonly property string calendarDir: {
        const base = Quickshell.env("XDG_DATA_HOME");
        return (base && base.length > 0 ? base : Quickshell.env("HOME") + "/.local/share") + "/calendar";
    }

    // Parsed events, sorted by start time then summary. Rebuilt wholesale on
    // every read rather than mutated in place: consumers bind to this array, and
    // reassigning is what makes them re-evaluate.
    readonly property var events: _sorted

    // True once at least one listing has completed, so the card can tell
    // "no events yet" apart from "not looked yet".
    readonly property bool loaded: _scanned

    // Shown in the card when there is nothing to list.
    readonly property string emptyReason: {
        if (!root.loaded)
            return qsTr("Reading calendar…");
        if (root._fileCount === 0)
            return qsTr("No .ics files in ") + root.calendarDir;
        return qsTr("No events on this day");
    }

    // Number of .ics files currently contributing events.
    readonly property int calendarCount: _fileCount

    // Bumped whenever events change, for views that would rather depend on a
    // version than on the array's identity.
    readonly property int revision: _revision

    // =========================================================================
    // Queries
    // =========================================================================

    // Events overlapping the given day, in start order.
    //
    // Overlap rather than "starts on the day": a multi-day event, or one that
    // begins at 23:00, still belongs on the timeline of the day it runs through,
    // which is what every calendar UI shows.
    function eventsForDay(date: var): var {
        const dayStart = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
        const dayEnd = new Date(date.getFullYear(), date.getMonth(), date.getDate() + 1).getTime();

        return _sorted.filter(ev => ev.end > dayStart && ev.start < dayEnd);
    }

    // Day-of-month -> true, for the month grid's event dots.
    //
    // Built per call because the grid only redraws the month it displays, and a
    // cached month map would need invalidating on every navigation.
    function eventDaysInMonth(year: int, month: int): var {
        const marks = {};
        const monthStart = new Date(year, month, 1).getTime();
        const monthEnd = new Date(year, month + 1, 1).getTime();

        for (let i = 0; i < _sorted.length; ++i) {
            const ev = _sorted[i];
            if (ev.end <= monthStart || ev.start >= monthEnd)
                continue;

            // Mark every day the event touches, so a multi-day entry dots each
            // date rather than only its first.
            const cursor = new Date(Math.max(ev.start, monthStart));
            cursor.setHours(0, 0, 0, 0);
            while (cursor.getTime() < Math.min(ev.end, monthEnd)) {
                if (cursor.getMonth() === month && cursor.getFullYear() === year)
                    marks[cursor.getDate()] = true;
                cursor.setDate(cursor.getDate() + 1);
            }
        }
        return marks;
    }

    // The next event starting at or after the reference time, or null.
    function nextEvent(from: var): var {
        const ref = from instanceof Date ? from.getTime() : Date.now();
        for (let i = 0; i < _sorted.length; ++i) {
            if (_sorted[i].start >= ref)
                return _sorted[i];
        }
        return null;
    }

    // =========================================================================
    // Internal State
    // =========================================================================

    readonly property var _sorted: _rebuild()
    property int _revision: 0
    property bool _scanned: false

    // path -> array of events parsed from that file.
    property var _byFile: ({})

    // Derived from the buckets rather than tracked separately, so the count can
    // never disagree with what was actually parsed.
    readonly property int _fileCount: Object.keys(_byFile).length

    // =========================================================================
    // Reading
    //
    // One shell loop over every .ics file in the directory, rather than one
    // process per file or a FileView per file. Each file is introduced by a
    // marker so the combined output splits back into per-file buckets.
    //
    // The directory is re-read on every tick instead of being watched. Deriving a
    // change signal from mtimes was tried first and rejected: `ls -1
    // --time-style=+%s` prints only the name, because --time-style has no effect
    // unless a time field is actually displayed, so every entry looked malformed
    // and nothing was ever read. Re-reading a handful of small files every 30s
    // costs a few milliseconds and needs no such subtlety.
    // =========================================================================

    Process {
        id: readProc
        command: [
            "sh", "-c",
            'for f in "$1"/*.ics; do [ -f "$f" ] || continue; printf "%s\\n" "###CTOSICS:$f"; cat "$f"; printf "\\n"; done',
            "ctos-calendar-read", root.calendarDir
        ]
        workingDirectory: "/"
        running: false

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root._scanned = true;

                const raw = text;
                const buckets = {};
                const parts = raw.split("###CTOSICS:");

                // parts[0] is whatever preceded the first marker; the rest are
                // "path\n<body>" pairs.
                for (let i = 1; i < parts.length; ++i) {
                    const chunk = parts[i];
                    const newline = chunk.indexOf("\n");
                    if (newline < 0)
                        continue;
                    const path = chunk.substring(0, newline).trim();
                    buckets[path] = root._parseIcs(chunk.substring(newline + 1));
                }

                root._byFile = buckets;
                root._touch();
            }
        }
    }

    Timer {
        id: readTimer
        // No filesystem watch, so this is the refresh. Frequent enough to feel
        // live after a sync, cheap enough to ignore.
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Still waiting on the previous run: skip rather than pile up forks.
            if (!readProc.running)
                readProc.running = true;
        }
    }

    // Force the derived arrays to be recomputed.
    function _touch(): void {
        _revision++;
    }

    function _rebuild(): var {
        const all = [];
        for (const path in _byFile) {
            const list = _byFile[path];
            for (let i = 0; i < list.length; ++i)
                all.push(list[i]);
        }
        all.sort((a, b) => (a.start - b.start) || a.summary.localeCompare(b.summary));
        return all;
    }

    // =========================================================================
    // iCalendar Parsing
    //
    // Scope is deliberately narrow: the properties the card renders, from VEVENT
    // blocks only. VTIMEZONE components are skipped rather than interpreted --
    // TZID names are resolved by the system zone database instead, which is
    // correct for the overwhelming majority of real-world zones and avoids
    // shipping a timezone compiler.
    // =========================================================================

    function _parseIcs(raw: string): var {
        if (!raw || raw.length === 0)
            return [];

        // RFC 5545 folds long lines: a newline followed by a single space or tab
        // continues the previous line. Unfolding first keeps the property parsing
        // below to one line per property.
        const text = raw.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "");
        const lines = text.split("\n");

        const out = [];
        let current = null;
        let inEvent = false;

        for (let i = 0; i < lines.length; ++i) {
            const line = lines[i];
            if (line.length === 0)
                continue;

            const colon = line.indexOf(":");
            if (colon < 0)
                continue;

            const rawName = line.substring(0, colon);
            const value = line.substring(colon + 1);

            // "DTSTART;TZID=Europe/Berlin:20261001T090000" -> name + params.
            const semi = rawName.indexOf(";");
            const name = (semi < 0 ? rawName : rawName.substring(0, semi)).toUpperCase();
            const params = semi < 0 ? "" : rawName.substring(semi + 1);

            if (name === "BEGIN" && value.trim().toUpperCase() === "VEVENT") {
                inEvent = true;
                current = { summary: "", location: "", description: "", categories: "", uid: "" };
                continue;
            }
            if (name === "END" && value.trim().toUpperCase() === "VEVENT") {
                if (inEvent && current) {
                    const built = _finishEvent(current);
                    if (built !== null)
                        out.push(built);
                }
                inEvent = false;
                current = null;
                continue;
            }
            if (!inEvent || !current)
                continue;

            switch (name) {
            case "SUMMARY":
                current.summary = _unescape(value);
                break;
            case "LOCATION":
                current.location = _unescape(value);
                break;
            case "DESCRIPTION":
                current.description = _unescape(value);
                break;
            case "CATEGORIES":
                current.categories = _unescape(value);
                break;
            case "UID":
                current.uid = value.trim();
                break;
            case "DTSTART":
                current.rawStart = value.trim();
                current.startParams = params;
                break;
            case "DTEND":
                current.rawEnd = value.trim();
                current.endParams = params;
                break;
            case "DURATION":
                // Only honoured when there is no DTEND; RFC 5545 says DTEND wins.
                current.rawDuration = value.trim();
                break;
            }
        }

        return out;
    }

    function _parseDuration(value: string): var {
        // P[n]W and P[n]DT[n]H[n]M[n]S.
        const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/
            .exec(value.trim().toUpperCase());
        if (!m)
            return 0;
        const sign = m[1] === "-" ? -1 : 1;
        const weeks = m[2] ? +m[2] : 0;
        const days = m[3] ? +m[3] : 0;
        const hours = m[4] ? +m[4] : 0;
        const minutes = m[5] ? +m[5] : 0;
        const seconds = m[6] ? +m[6] : 0;
        return sign * (((weeks * 7 + days) * 24 + hours) * 3600 + minutes * 60 + seconds) * 1000;
    }

    function _finishEvent(ev: var): var {
        if (!ev.rawStart)
            return null; // An event with no start cannot be placed on a timeline.

        const start = _parseDateTime(ev.rawStart, ev.startParams);
        if (start === null)
            return null;

        let end = null;
        if (ev.rawEnd)
            end = _parseDateTime(ev.rawEnd, ev.endParams);
        else if (ev.rawDuration) {
            // _parseDuration is annotated `: var`, not `: number`, despite always
            // returning a Number. Qt 6.9's strict checking treats a `number` return
            // annotation on a QML method as void and logs "3600000 should be
            // coerced to void because the function called is insufficiently
            // annotated" at the call site. The value is retained today, so this is
            // cosmetic, but it is emitted as an error and will not be in future
            // versions.
            const durationMs = _parseDuration(ev.rawDuration);
            end = new Date(start.getTime() + durationMs);
        }
        else
            end = new Date(start.getTime()); // DTSTART-only: instantaneous.

        return {
            uid: ev.uid,
            summary: ev.summary.length > 0 ? ev.summary : qsTr("(No title)"),
            location: ev.location,
            description: ev.description,
            category: ev.categories.split(",")[0].trim(),
            start: start.getTime(),
            end: end.getTime(),
            allDay: _isAllDay(ev.rawStart, ev.startParams)
        };
    }

    // DTSTART;VALUE=DATE:20261001                -> all-day, local midnight
    // DTSTART:20261001T090000Z                   -> UTC
    // DTSTART;TZID=Asia/Kolkata:20261001T090000  -> local time in that zone
    // DTSTART:20261001T090000                    -> floating, treated as local
    function _parseDateTime(value: string, params: string): var {
        if (value.length < 8)
            return null;

        const dateOnly = /^(\d{4})(\d{2})(\d{2})$/.exec(value);
        if (dateOnly) {
            const d = new Date(+dateOnly[1], +dateOnly[2] - 1, +dateOnly[3], 0, 0, 0, 0);
            return isNaN(d.getTime()) ? null : d;
        }

        const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/.exec(value);
        if (!m)
            return null;

        const year = +m[1], month = +m[2] - 1, day = +m[3];
        const hour = +m[4], minute = +m[5], second = +m[6];

        // Trailing Z is UTC. Constructed through Date.UTC so the local zone of
        // the machine running the shell does not shift the instant.
        if (m[7] === "Z") {
            const utc = new Date(Date.UTC(year, month, day, hour, minute, second));
            return isNaN(utc.getTime()) ? null : utc;
        }

        // A TZID names a zone this service does not carry a database for. Falling
        // back to local time is the least surprising outcome for the common case
        // where the shell runs in the user's own zone, and the alternative --
        // shipping a full tz database -- is a large dependency for a margin of
        // correctness on events in other zones.
        return new Date(year, month, day, hour, minute, second);
    }

    function _isAllDay(value: string, params: string): bool {
        if (/VALUE=DATE/i.test(params || ""))
            return true;
        // A bare YYYYMMDD with no time component is an all-day date.
        return /^\d{8}$/.test(value);
    }

    // RFC 5545 TEXT escaping: \n \N \, \; \\.
    function _unescape(value: string): string {
        let out = "";
        for (let i = 0; i < value.length; ++i) {
            const ch = value[i];
            if (ch !== "\\" || i + 1 >= value.length) {
                out += ch;
                continue;
            }
            const next = value[++i];
            if (next === "n" || next === "N")
                out += "\n";
            else
                out += next;
        }
        return out.trim();
    }
}