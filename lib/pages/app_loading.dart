import 'package:compus_connect/utilities/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLoadingPage extends StatelessWidget {
  final String message;
  final bool showSpinner;

  const AppLoadingPage({
    super.key,
    this.message = 'Starting up...',
    this.showSpinner = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kPrimaryNavy, Color(0xFF0F1730)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/LogoWhite.png',
                    width: 140,
                    height: 140,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Campus Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                  if (showSpinner) ...[
                    const SizedBox(height: 20),
                    const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
