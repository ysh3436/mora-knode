using System.Text;

namespace MoraKnode.Infrastructure;

/// <summary>
/// Minimal RFC 5545 (iCalendar) parser — extracts <c>VEVENT</c> entries with
/// only the fields we care about for holiday display: DTSTART (date) and
/// SUMMARY (label). Skips DTEND/DURATION/RRULE etc. so a recurring event is
/// surfaced once at its start; for holiday calendars the publisher already
/// expands recurrences on the year boundary, so this is fine in practice.
///
/// Custom parser instead of pulling in <c>Ical.Net</c> — the format we need
/// is a tiny subset and a 100-line dependency-free parser is easier to audit
/// and keeps the package tree lean.
/// </summary>
public static class IcsParser
{
    public record IcsEvent(DateTime Date, string Summary);

    public static IEnumerable<IcsEvent> Parse(string ics)
    {
        // Step 1 — line unfolding (RFC 5545 §3.1): a continuation line starts
        // with whitespace and joins to the previous line with the leading
        // whitespace stripped.
        var unfolded = new List<string>();
        foreach (var line in ics.Replace("\r\n", "\n").Split('\n'))
        {
            if (line.Length > 0 && (line[0] == ' ' || line[0] == '\t'))
            {
                if (unfolded.Count == 0) continue;
                unfolded[^1] += line.Substring(1);
            }
            else
            {
                unfolded.Add(line);
            }
        }

        // Step 2 — walk events, extracting DTSTART + SUMMARY.
        var inEvent = false;
        DateTime? eventDate = null;
        string? eventSummary = null;

        foreach (var raw in unfolded)
        {
            var line = raw.TrimEnd('\r');
            if (line == "BEGIN:VEVENT")
            {
                inEvent = true;
                eventDate = null;
                eventSummary = null;
                continue;
            }
            if (line == "END:VEVENT")
            {
                if (inEvent && eventDate.HasValue && !string.IsNullOrWhiteSpace(eventSummary))
                {
                    yield return new IcsEvent(eventDate.Value, DecodeText(eventSummary));
                }
                inEvent = false;
                continue;
            }
            if (!inEvent) continue;

            var colonIdx = line.IndexOf(':');
            if (colonIdx <= 0) continue;
            var keyPart = line.Substring(0, colonIdx);
            var valuePart = line.Substring(colonIdx + 1);
            // keyPart can be "DTSTART" or "DTSTART;VALUE=DATE" — only the
            // bare property name matters for our switch.
            var keyName = keyPart.Split(';')[0];
            switch (keyName)
            {
                case "DTSTART":
                    eventDate = ParseIcsDate(valuePart);
                    break;
                case "SUMMARY":
                    eventSummary = valuePart;
                    break;
            }
        }
    }

    /// <summary>
    /// Accepts the three iCal date forms we care about and normalises to UTC
    /// midnight of the calendar day. Times are dropped — for "is this day a
    /// holiday" the time-of-day is irrelevant.
    /// </summary>
    static DateTime? ParseIcsDate(string raw)
    {
        var s = raw.Trim();
        // YYYYMMDD (date-only, the all-day form most holiday feeds use)
        if (s.Length == 8 && long.TryParse(s, out _))
        {
            return BuildUtcMidnight(s);
        }
        // YYYYMMDDTHHMMSSZ (UTC datetime) or YYYYMMDDTHHMMSS (local datetime).
        // We only need the date part either way.
        if (s.Length >= 15 && s[8] == 'T')
        {
            return BuildUtcMidnight(s.Substring(0, 8));
        }
        return null;
    }

    static DateTime BuildUtcMidnight(string yyyymmdd)
    {
        var y = int.Parse(yyyymmdd.Substring(0, 4));
        var m = int.Parse(yyyymmdd.Substring(4, 2));
        var d = int.Parse(yyyymmdd.Substring(6, 2));
        return new DateTime(y, m, d, 0, 0, 0, DateTimeKind.Utc);
    }

    /// <summary>
    /// RFC 5545 text-value escapes: <c>\\</c> → <c>\</c>, <c>\;</c> → <c>;</c>,
    /// <c>\,</c> → <c>,</c>, <c>\n</c>/<c>\N</c> → newline. Done in two passes
    /// via a sentinel so the unescape of <c>\\</c> doesn't itself get
    /// interpreted as an escape.
    /// </summary>
    static string DecodeText(string s)
    {
        if (string.IsNullOrEmpty(s)) return s;
        var sb = new StringBuilder(s.Length);
        for (var i = 0; i < s.Length; i++)
        {
            if (s[i] == '\\' && i + 1 < s.Length)
            {
                var next = s[i + 1];
                switch (next)
                {
                    case '\\': sb.Append('\\'); i++; continue;
                    case ';': sb.Append(';'); i++; continue;
                    case ',': sb.Append(','); i++; continue;
                    case 'n':
                    case 'N': sb.Append('\n'); i++; continue;
                }
            }
            sb.Append(s[i]);
        }
        return sb.ToString();
    }
}
