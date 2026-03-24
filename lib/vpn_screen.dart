import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/data/theme_provider.dart';
import 'package:vpn/vpn_power_button.dart';
import 'package:vpn/data/vpn_provider.dart';

import 'vpn_service/services/vpn_status.dart';

class VpnScreen extends ConsumerWidget {
  const VpnScreen({super.key});

  Color mapPingToColor(int ping) {
    if (ping < 100) return Colors.green;
    if (ping < 200) return Colors.yellow;
    return Colors.red;
  }

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
      default:
        return 'MEOW';
    }
  }

  Color mapStatusColor(VpnStatus status, bool isDark) {
    Color statusColor;

    if (status == VpnStatus.error) {
      statusColor = Colors.red;
    } else if (status == VpnStatus.connected) {
      statusColor = Colors.green;
    } else {
      statusColor = isDark ? CupertinoColors.systemGrey : CupertinoColors.black;
    }

    return statusColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appThemeProvider) == Brightness.dark;

    final statusAsync = ref.watch(vpnStatusProvider);
    final pingAsync = ref.watch(vpnControllerProvider);

    final status = statusAsync.value ?? VpnStatus.disconnected;
    final isConnected = status == VpnStatus.connected;
    final isConnecting = status == VpnStatus.connecting;

    final Color statusColor = mapStatusColor(status, isDark);
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
                mapStatus(status),
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
              const SizedBox(height: 12),
              if (isConnecting) ...[Text("Connecting, please wait...")],
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? VpnTheme.surfaceDark
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? VpnTheme.primary.withOpacity(0.3)
                        : CupertinoColors.transparent,
                  ),
                ),
                child: CupertinoListTile(
                  padding: EdgeInsets.symmetric(vertical: 0, horizontal: 4),
                  leadingToTitle: 12,
                  leading: const Icon(
                    CupertinoIcons.globe,
                    color: VpnTheme.primary,
                  ),
                  title: const Text('🇸🇪 Sweden - Stockholm'),
                  trailing: Text(
                    '${pingAsync.value ?? defaultPingValue} ms',
                    style: TextStyle(
                      color: mapPingToColor(
                        pingAsync.value ?? defaultPingValue,
                      ),
                    ),
                  ),
                  onTap: () {},
                ),
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
