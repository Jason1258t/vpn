import 'package:flutter/material.dart';
import 'package:vpn/data/protocol_manager.dart';
import 'package:vpn/theme.dart';

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

  static final double _childWidth = _width / 2 - 4 - 1;
  static final double _childHeight = _height - 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _width,
      height: _height,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VpnTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VpnTheme.primary.withValues(alpha: 0.3), width: 1),
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
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: _childWidth,
                height: _childHeight,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: toggle,
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
                height: _childHeight,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: toggle,
                  child: Text(
                    "XHttp",
                    style: TextStyle(
                      color: protocol == AvailableProtocols.vlessXHttp
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
