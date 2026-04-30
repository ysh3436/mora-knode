using System.Text.Json.Serialization;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Timeline
{
    public DateTime? Start { get; set; }
    public DateTime? End { get; set; }

    // ADR-009: per-timeline all-day flag. Default true so existing data behaves
    // as date-range (the legacy semantics). When true, repos normalize Start to
    // 00:00:00.000 UTC and End to 23:59:59.999 UTC of their respective dates on
    // save. BsonDefaultValue covers documents written before this field existed.
    [BsonDefaultValue(true)]
    public bool IsAllDay { get; set; } = true;

    [JsonIgnore]
    [BsonIgnore]
    public bool IsEmpty => Start is null && End is null;

    public bool Equals(Timeline? other) =>
        other is not null
        && Start == other.Start
        && End == other.End
        && IsAllDay == other.IsAllDay;
}
