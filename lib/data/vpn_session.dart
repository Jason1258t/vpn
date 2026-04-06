import '../vpn_service/vpn_status.dart';

class VpnSession {
  DateTime startTime;
  DateTime? endTime;

  VpnSession(this.startTime, {this.endTime});
}

class VpnSessionStatus {
  final int ping;
  final VpnStatus status;
  final DateTime? sessionStartTime;
  final String protocol;

  VpnSessionStatus({
    this.ping = defaultPingValue,
    this.sessionStartTime,
    this.status = VpnStatus.disconnected,
    required this.protocol,
  });

  Duration? get duration => sessionStartTime != null
      ? DateTime.now().difference(sessionStartTime!)
      : null;

  VpnSessionStatus copyWith({
    VpnStatus? status,
    int? ping,
    DateTime? sessionStartTime,
    String? protocol,
  }) => VpnSessionStatus(
    status: status ?? this.status,
    ping: ping ?? this.ping,
    sessionStartTime: sessionStartTime ?? this.sessionStartTime,
    protocol: protocol ?? this.protocol,
  );
}
