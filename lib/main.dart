import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/theme_provider.dart';
import 'package:vpn/vpn_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(ProviderScope(child: const VpnApp()));
}

class VpnApp extends ConsumerWidget {
  const VpnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(appThemeProvider);

    return CupertinoApp(
      title: "ZXC VPN",
      theme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: VpnTheme.primary,
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? VpnTheme.gothicBlack
            : CupertinoColors.systemBackground,
        barBackgroundColor: brightness == Brightness.dark
            ? VpnTheme.surfaceDark.withOpacity(0.8)
            : CupertinoColors.systemBackground.withOpacity(0.8),
      ),
      home: const VpnScreen(),
    );
  }
}

