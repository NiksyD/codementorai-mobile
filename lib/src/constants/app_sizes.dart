import 'package:flutter/material.dart';

abstract class AppSizes {
  // Spacing & Padding
  static const double p4 = 4.0;
  static const double p8 = 8.0;
  static const double p12 = 12.0;
  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;
  static const double p48 = 48.0;

  // Gaps
  static const SizedBox gapH4 = SizedBox(height: p4);
  static const SizedBox gapH8 = SizedBox(height: p8);
  static const SizedBox gapH12 = SizedBox(height: p12);
  static const SizedBox gapH16 = SizedBox(height: p16);
  static const SizedBox gapH24 = SizedBox(height: p24);
  static const SizedBox gapH32 = SizedBox(height: p32);

  static const SizedBox gapW4 = SizedBox(width: p4);
  static const SizedBox gapW8 = SizedBox(width: p8);
  static const SizedBox gapW12 = SizedBox(width: p12);
  static const SizedBox gapW16 = SizedBox(width: p16);
  static const SizedBox gapW24 = SizedBox(width: p24);
  static const SizedBox gapW32 = SizedBox(width: p32);
}
