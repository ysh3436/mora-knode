import 'resource.dart';

/// Mirrors the backend's TokenSummary record. Surfaces in the agent
/// management UI so the user can see what credentials exist and which
/// one is currently active. Raw token strings are never returned by
/// this endpoint — only [lastFour] for visual matching.
class AgentTokenSummary {
  final String id;
  final String lastFour;
  final DateTime createdAt;
  final DateTime? revokedAt;
  final DateTime? lastSeenAt;
  final bool isActive;

  const AgentTokenSummary({
    required this.id,
    required this.lastFour,
    required this.createdAt,
    required this.revokedAt,
    required this.lastSeenAt,
    required this.isActive,
  });

  factory AgentTokenSummary.fromJson(Map<String, dynamic> json) =>
      AgentTokenSummary(
        id: json['id'] as String,
        lastFour: json['lastFour'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        revokedAt: json['revokedAt'] == null
            ? null
            : DateTime.parse(json['revokedAt'] as String).toUtc(),
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.parse(json['lastSeenAt'] as String).toUtc(),
        isActive: json['isActive'] as bool? ?? false,
      );
}

/// Response shape from POST /api/agents — wraps the freshly-created agent
/// resource together with the one-time-visible raw token. The UI must
/// display [rawToken] prominently and warn that it cannot be recovered.
class CreatedAgent {
  final Resource agent;
  final String rawToken;
  final String lastFour;

  const CreatedAgent({
    required this.agent,
    required this.rawToken,
    required this.lastFour,
  });

  factory CreatedAgent.fromJson(Map<String, dynamic> json) => CreatedAgent(
        agent: Resource.fromJson(json['agent'] as Map<String, dynamic>),
        rawToken: json['rawToken'] as String,
        lastFour: json['lastFour'] as String,
      );
}

/// Response shape from POST /api/agents/{id}/rotate — same one-time-reveal
/// contract as [CreatedAgent], minus the resource (it didn't change).
class RotatedToken {
  final String rawToken;
  final String lastFour;

  const RotatedToken({required this.rawToken, required this.lastFour});

  factory RotatedToken.fromJson(Map<String, dynamic> json) => RotatedToken(
        rawToken: json['rawToken'] as String,
        lastFour: json['lastFour'] as String,
      );
}
