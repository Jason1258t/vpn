import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/widgets/protocol_switch.dart';
import 'package:vpn/widgets/stopwatch.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/data/theme_provider.dart';
import 'package:vpn/widgets/vpn_power_button.dart';
import 'package:vpn/data/vpn_provider.dart';

import 'vpn_service/vpn_status.dart';
import 'widgets/server_info.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  String mapStatus(VpnStatus status) {
    switch (status) {
      case VpnStatus.disconnected:
        return 'DISCONNECTED';
      case VpnStatus.connected:
        return 'CONNECTED';
      case VpnStatus.connecting:
        return 'CONNECTING';
      case VpnStatus.error:
        return 'ERROR';
    }
  }

  Color mapStatusColor(VpnStatus status, bool isDark) {
    Color statusColor;

    if (status == VpnStatus.error) {
      statusColor = VpnTheme.statusBad;
    } else if (status == VpnStatus.connected) {
      statusColor = VpnTheme.statusNice;
    } else {
      statusColor = isDark ? CupertinoColors.systemGrey : CupertinoColors.black;
    }

    return statusColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appThemeProvider) == Brightness.dark;

    final session = ref.watch(vpnControllerProvider);

    final isConnected = session.status == VpnStatus.connected;
    final isConnecting = session.status == VpnStatus.connecting;

    final Color statusColor = mapStatusColor(session.status, isDark);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ZXC VPN'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
          ),
          onPressed: () => _switchTheme(context),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Text(
                mapStatus(session.status),
                style: TextStyle(
                  letterSpacing: 4,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              VpnPowerButton(
                enabled: isConnected,
                onTap: () {
                  if (isConnecting) return;
                  ref.read(vpnControllerProvider.notifier).toggleConnection();
                },
              ),
              const SizedBox(height: 24),
              if (isConnecting) ...[Text("Connecting, please wait...")],
              if (isConnected && session.sessionStartTime != null) ...[
                StopwatchWidget(start: session.sessionStartTime!),
              ],
              const Spacer(),
              ServerInfo(
                ping: session.ping,
                flag: '🇸🇪',
                name: 'Sweden - Stockholm',
              ),
              const SizedBox(height: 24),
              ProtocolSwitch(
                protocol: session.protocol,
                toggle: () =>
                    ref.read(vpnControllerProvider.notifier).toggleProtocol(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  _switchTheme(BuildContext context) async {
    await showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text("Предупреждение"),
        content: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            "Тебе не надо менять тему, поверь. Там такой ужас пока, из-за того что разрабу плевать на светлую тему",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: Text("Ок", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
