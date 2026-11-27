import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Branded first frame shown while local app services are being prepared.
///
/// Android 12 requires a flat-color system splash. This Flutter surface replaces
/// it as soon as the engine is ready and paints the full 7xPlay SVG background.
class StartupSplash extends StatelessWidget {
  const StartupSplash({
    this.hasError = false,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final bool hasError;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoWidth =
                (constraints.maxWidth * 0.78).clamp(220.0, 620.0).toDouble();

            return Stack(
              fit: StackFit.expand,
              children: [
                SvgPicture.asset(
                  'assets/images/7xplay_splash_background.svg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                Center(
                  child: Image.asset(
                    'assets/images/7xplay_wordmark.png',
                    width: logoWidth,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                if (hasError)
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 28,
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '7xPlay could not finish starting.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (errorMessage != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              errorMessage!,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: onRetry,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Text(
                                'Try again',
                                style: TextStyle(
                                  color: Color(0xFF17152B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
