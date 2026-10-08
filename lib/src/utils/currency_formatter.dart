import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Utility class for formatting currency and converting USD prices to PHP Peso.
class CurrencyFormatter {
  CurrencyFormatter._();

  static double _liveRate = 58.0;
  static bool _hasFetched = false;

  /// Returns current exchange rate (USD to PHP)
  static double get liveRate => _liveRate;

  /// Fetch live rate from API endpoint with 3s timeout and fallback to 58.0
  static Future<double> fetchLiveRate({String? apiUrl}) async {
    if (_hasFetched) return _liveRate;
    try {
      final String base = apiUrl ?? 'https://codementorai-ejkd.onrender.com';
      final http.Response res = await http.get(Uri.parse('$base/api/currency/rate')).timeout(
        const Duration(seconds: 3),
      );
      if (res.statusCode == 200) {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['rate'] is num) {
          _liveRate = (data['rate'] as num).toDouble();
          _hasFetched = true;
        }
      }
    } catch (e) {
      debugPrint('[CurrencyFormatter] Using fallback exchange rate 58.0: $e');
    }
    return _liveRate;
  }

  /// Formats amount in PHP with peso sign and thousand separators.
  /// Example: 1682.0 -> "₱1,682.00"
  static String formatPHP(double amountInPHP, {bool showDecimals = true}) {
    if (amountInPHP <= 0) return 'Free';
    final List<String> parts =
        amountInPHP.toStringAsFixed(showDecimals ? 2 : 0).split('.');
    final String integerPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    if (showDecimals && parts.length > 1) {
      return '₱$integerPart.${parts[1]}';
    }
    return '₱$integerPart';
  }

  /// Converts USD to PHP and formats with "₱".
  /// Example: 29.0 USD -> "₱1,682.00"
  static String formatConvertedPhp(double usdAmount,
      {double? rate, bool showDecimals = true}) {
    if (usdAmount <= 0) return 'Free';
    final double effectiveRate = rate ?? _liveRate;
    return formatPHP(usdAmount * effectiveRate, showDecimals: showDecimals);
  }
}
