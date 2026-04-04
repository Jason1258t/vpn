import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vpn/theme.dart';
import 'package:vpn/data/theme_provider.dart';
import 'package:vpn/vpn_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load();

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
            ? VpnTheme.surfaceDark.withValues(alpha:  .8)
            : CupertinoColors.systemBackground.withValues(alpha: .8),
      ),
      home: const VpnScreen(),
    );
  }
}
