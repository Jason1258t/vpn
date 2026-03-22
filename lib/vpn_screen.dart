import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/theme_provider.dart';
import 'package:vpn/vpn_provider.dart';
import 'package:vpn/vpn_repository.dart';

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
      case VpnStatus.connection:
        return 'CONNECTING';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(appThemeProvider) == Brightness.dark;

    final statusAsync = ref.watch(vpnStatusProvider);
    final pingAsync = ref.watch(vpnControllerProvider);

    final status = statusAsync.value ?? VpnStatus.disconnected;
    final isConnected = status == VpnStatus.connected;
    final isConnecting = status == VpnStatus.connection;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ZXC VPN'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            isDark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
          ),
          onPressed: () {
            ref.read(appThemeProvider.notifier).toggle();
          },
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Статус подключения
              Text(
                mapStatus(status),
                style: TextStyle(
                  letterSpacing: 4,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? CupertinoColors.systemGrey
                      : CupertinoColors.black,
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
              if (isConnecting)...[Text("Connecting, please wait...")],
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
                  leading: const Icon(
                    CupertinoIcons.globe,
                    color: VpnTheme.primary,
                  ),
                  title: const Text('Sweden - Stockholm'),
                  trailing: Text(
                    '${pingAsync.value ?? 5000} ms',
                    style: TextStyle(
                      color: mapPingToColor(pingAsync.value ?? 5000),
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
}

class VpnPowerButton extends StatelessWidget {
  const VpnPowerButton({super.key, required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: VpnTheme.primary.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
        border: enabled ? null : Border.all(color: VpnTheme.primary, width: 3),
        gradient: enabled
            ? RadialGradient(colors: [VpnTheme.primary, Color(0xFF3C096C)])
            : null,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: const Icon(
          CupertinoIcons.power,
          size: 80,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}
