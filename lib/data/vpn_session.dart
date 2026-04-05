import '../vpn_service/services/vpn_status.dart';

class VpnSessionStatus {
  final int ping;
  final VpnStatus status;
  final DateTime? sessionStartTime;

  VpnSessionStatus({
    this.ping = defaultPingValue,
    this.sessionStartTime,
    this.status = VpnStatus.disconnected,
  });

  Duration? get duration => sessionStartTime != null
      ? DateTime.now().difference(sessionStartTime!)
      : null;

  VpnSessionStatus copyWith({
    VpnStatus? status,
    int? ping,
    DateTime? sessionStartTime,
  }) => VpnSessionStatus(
    status: status ?? this.status,
    ping: ping ?? this.ping,
    sessionStartTime: sessionStartTime ?? this.sessionStartTime,
  );
}