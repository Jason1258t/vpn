import 'package:flutter/cupertino.dart';
import 'package:vpn/theme.dart';

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
