using System.Text.Json.Serialization;
using MongoDB.Bson.Serialization.Attributes;

namespace MoraKnode.Domain;

public class Timeline
{
    public DateTime? Start { get; set; }
    public DateTime? End { get; set; }

    [JsonIgnore]
    [BsonIgnore]
    public bool IsEmpty => Start is null && End is null;

    public bool Equals(Timeline? other) =>
        other is not null && Start == other.Start && End == other.End;
}
