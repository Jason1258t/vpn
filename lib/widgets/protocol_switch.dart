import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vpn/data/protocol_manager.dart';
import 'package:vpn/theme.dart';

class ProtocolSwitch extends StatelessWidget {
  ProtocolSwitch({
    super.key,
    required this.currentProtocol,
    required this.toggle,
    required this.protocols,
    this.width = 200,
    this.height = 50,
  }) {
    _prepareSizes();
  }

  final String currentProtocol;
  final VoidCallback toggle;

  final List<ProtocolViewData> protocols;

  final double width;
  final double height;

  late final double _childWidth;
  late final double _childHeight;

  static final double _padding = 4;
  static final double _borderWidth = 1;

  void _prepareSizes() {
    _childWidth = (width - _padding * 2 - _borderWidth * 2) / protocols.length;
    _childHeight = height - _padding * 2 - _borderWidth * 2;
  }

  @override
  Widget build(BuildContext context) {
    log(protocols.toString());
    log(currentProtocol);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: VpnTheme.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: VpnTheme.primary.withValues(alpha: 0.3),
          width: _borderWidth,
        ),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            top: 0,
            left:
                _childWidth *
                protocols.indexWhere((p) => p.id == currentProtocol),
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
              for (ProtocolViewData p in protocols) ...[
                Container(
                  width: _childWidth,
                  height: _childHeight,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: toggle,
                    child: Text(
                      p.name,
                      style: TextStyle(
                        color: currentProtocol == p.id
                            ? Colors.white
                            : VpnTheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
