using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

/// <summary>
/// Org-level work calendar. Single document for MVP (id = "default").
/// Per-resource overrides are M2+ — see ADR-009 §3.
/// </summary>
public class WorkCalendar
{
    public const string DefaultId = "default";

    [BsonId]
    public string Id { get; set; } = DefaultId;

    public WorkDayMask WorkDays { get; set; } = WorkDayMask.MonToFri;

    // Stored as minutes-since-midnight to keep BSON portable. Helpers below
    // convert to/from TimeOnly for app code.
    public int DailyStartMinutes { get; set; } = 9 * 60;     // 09:00
    public int DailyEndMinutes { get; set; } = 18 * 60;      // 18:00

    public string Timezone { get; set; } = "Asia/Seoul";

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    [BsonIgnore]
    public TimeOnly DailyStart
    {
        get => TimeOnly.FromTimeSpan(TimeSpan.FromMinutes(DailyStartMinutes));
        set => DailyStartMinutes = value.Hour * 60 + value.Minute;
    }

    [BsonIgnore]
    public TimeOnly DailyEnd
    {
        get => TimeOnly.FromTimeSpan(TimeSpan.FromMinutes(DailyEndMinutes));
        set => DailyEndMinutes = value.Hour * 60 + value.Minute;
    }

    [BsonIgnore]
    public int DailyWorkMinutes => Math.Max(0, DailyEndMinutes - DailyStartMinutes);

    public bool IsWorkDay(DayOfWeek day)
    {
        var mask = day switch
        {
            DayOfWeek.Monday => WorkDayMask.Mon,
            DayOfWeek.Tuesday => WorkDayMask.Tue,
            DayOfWeek.Wednesday => WorkDayMask.Wed,
            DayOfWeek.Thursday => WorkDayMask.Thu,
            DayOfWeek.Friday => WorkDayMask.Fri,
            DayOfWeek.Saturday => WorkDayMask.Sat,
            DayOfWeek.Sunday => WorkDayMask.Sun,
            _ => WorkDayMask.None
        };
        return (WorkDays & mask) != 0;
    }

    /// <summary>
    /// 24/7 fallback used when no document exists.
    /// </summary>
    public static WorkCalendar Fallback247() => new()
    {
        Id = DefaultId,
        WorkDays = WorkDayMask.All,
        DailyStartMinutes = 0,
        DailyEndMinutes = 24 * 60,
        Timezone = "UTC"
    };
}
