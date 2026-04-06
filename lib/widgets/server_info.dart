import 'package:flutter/cupertino.dart';
import 'package:vpn/theme.dart';

class ServerInfo extends StatelessWidget {
  const ServerInfo({
    super.key,
    required this.flag,
    required this.name,
    required this.ping,
  });

  final String flag;
  final String name;
  final int ping;

  Color _mapPingToColor(int ping) {
    if (ping == -1) return VpnTheme.statusBad;
    if (ping < 150) return VpnTheme.statusNice;
    if (ping < 500) return VpnTheme.statusNormal;
    return VpnTheme.statusBad;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VpnTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VpnTheme.primary.withValues(alpha: 0.3)),
      ),
      child: CupertinoListTile(
        leadingToTitle: 8,
        leading: const Icon(CupertinoIcons.globe, color: VpnTheme.primary),
        title:  Text('$flag $name'),
        trailing: Text(
          ping != -1 ? '$ping ms' : "ERROR",
          style: TextStyle(color: _mapPingToColor(ping)),
        ),
        onTap: () {},
      ),
    );
  }
}
