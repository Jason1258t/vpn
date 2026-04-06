import 'dart:async';

import 'package:flutter/cupertino.dart';

class StopwatchWidget extends StatefulWidget {
  const StopwatchWidget({super.key, required this.start});

  final DateTime start;

  @override
  State<StopwatchWidget> createState() => _StopwatchWidgetState();
}

class _StopwatchWidgetState extends State<StopwatchWidget> {
  String stringDuration() {
    final duration = DateTime.now().difference(widget.start);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    String result = '';
    if (hours != '00') {
      result = '$hours : ';
    }
    result += '$minutes : $seconds';

    return result;
  }

  late final Timer _timer;

  @override
  void initState() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    super.initState();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      stringDuration(),
      style: TextStyle(
        letterSpacing: 1.4,
        fontWeight: FontWeight.w300,
        fontSize: 18,
        color: CupertinoColors.systemGrey,
      ),
    );
  }
}
