import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/stopwatch.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/data/theme_provider.dart';
import 'package:vpn/vpn_power_button.dart';
import 'package:vpn/data/vpn_provider.dart';

import 'data/protocol_manager.dart';
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? VpnTheme.surfaceDark
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? VpnTheme.primary.withValues(alpha: 0.3)
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
                    '${session.ping} ms',
                    style: TextStyle(color: mapPingToColor(session.ping)),
                  ),
                  onTap: () {},
                ),
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

class ProtocolSwitch extends StatelessWidget {
  const ProtocolSwitch({
    super.key,
    required this.protocol,
    required this.toggle,
  });

  final String protocol;
  final VoidCallback toggle;

  static const double _width = 200;
  static const double _height = 50;

  static final double _childWidth = _width / 2 - 8;
  static final double _childHeight = _height - 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VpnTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VpnTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            top: 0,
            left: protocol == AvailableProtocols.vlessReality ? 0 : _childWidth,
            curve: Curves.easeInOut,
            child: Container(
              width: _childWidth,
              height: _childHeight,
              decoration: BoxDecoration(
                color: VpnTheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: _childWidth,
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: toggle,
                  child: Text(
                    "Reality",
                    style: TextStyle(
                      color: protocol == AvailableProtocols.vlessReality
                          ? Colors.white
                          : VpnTheme.primary,
                    ),
                  ),
                ),
              ),
              Container(
                width: _childWidth,
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: toggle,
                  child: Text(
                    "XHttp",
                    style: TextStyle(
                      color: protocol == AvailableProtocols.vlessXHttpTLS
                          ? Colors.white
                          : VpnTheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
