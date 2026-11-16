import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Shown instead of the app when it cannot start, for example when this build
/// shipped without its configuration. Without it the app would stay on the
/// launch screen with nothing to tell the learner (or us) what went wrong.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeMentorAI',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Image.asset(
                    'assets/images/app_logo.png',
                    width: 64.0,
                    height: 64.0,
                  ),
                  const SizedBox(height: 24.0),
                  const Text(
                    'CodeMentorAI could not start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkTextPrimary,
                      fontSize: 18.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 14.0,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
