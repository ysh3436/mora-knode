using System.Security.Cryptography;
using System.Text;

namespace MoraKnode.Auth;

/// <summary>
/// Issues and verifies agent tokens. Format: <c>mk_{43-char base64url}</c>.
/// 32 random bytes → URL-safe base64 (no padding) yields 43 chars; the
/// "mk_" prefix is for grep-based leak detection (GitHub PAT pattern).
/// Storage: SHA-256 hex of the post-prefix part only, so that the prefix
/// could change later without invalidating stored hashes.
/// </summary>
public static class TokenGenerator
{
    public const string Prefix = "mk_";

    public sealed record Issued(string Raw, string Hash, string LastFour);

    public static Issued Issue()
    {
        var bytes = RandomNumberGenerator.GetBytes(32);
        var rawBody = Convert.ToBase64String(bytes)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
        var raw = Prefix + rawBody;
        var hash = HashBody(rawBody);
        var lastFour = rawBody[^4..];
        return new Issued(raw, hash, lastFour);
    }

    /// <summary>Returns null when the input does not look like an mk_ token.</summary>
    public static string? HashOf(string presented)
    {
        if (string.IsNullOrEmpty(presented)) return null;
        if (!presented.StartsWith(Prefix)) return null;
        var body = presented[Prefix.Length..];
        if (body.Length == 0) return null;
        return HashBody(body);
    }

    private static string HashBody(string body)
    {
        var hash = SHA256.HashData(Encoding.ASCII.GetBytes(body));
        var sb = new StringBuilder(hash.Length * 2);
        foreach (var b in hash) sb.Append(b.ToString("x2"));
        return sb.ToString();
    }
}
