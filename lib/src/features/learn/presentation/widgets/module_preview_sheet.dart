import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common_widgets/language_avatar_stack.dart';
import '../../../../constants/app_colors.dart';
import '../../../../utils/currency_formatter.dart';
import '../../domain/pathway_model.dart';

class ModulePreviewSheet extends StatefulWidget {
  const ModulePreviewSheet({
    super.key,
    required this.module,
    required this.onEnroll,
  });

  final PathwayModel module;
  final Future<void> Function(String tier) onEnroll;

  static Future<void> show(
    BuildContext context, {
    required PathwayModel module,
    required Future<void> Function(String tier) onEnroll,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext ctx) => ModulePreviewSheet(
        module: module,
        onEnroll: onEnroll,
      ),
    );
  }

  @override
  State<ModulePreviewSheet> createState() => _ModulePreviewSheetState();
}

class _ModulePreviewSheetState extends State<ModulePreviewSheet> {
  int _walletBalance = 250;
  bool _isLoadingWallet = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final String? userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final Map<String, dynamic>? data = await Supabase.instance.client
            .from('user_wallets')
            .select('balance_coins')
            .eq('user_id', userId)
            .maybeSingle();
        if (data != null && data['balance_coins'] != null) {
          if (mounted) {
            setState(() {
              _walletBalance = (data['balance_coins'] as num).toInt();
              _isLoadingWallet = false;
            });
          }
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _handleUnlock(int priceCoins) async {
    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to unlock challenges')),
      );
      return;
    }

    if (_walletBalance < priceCoins) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.onEnroll('pro');
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unlock: $e')),
        );
      }
    }
  }

  String _cleanCoachName(String? name) {
    if (name == null || name.trim().isEmpty) return 'CodeMentor AI';
    final String cleaned = name.replaceAll(RegExp(r'TEST\d*'), '').trim();
    return cleaned.isNotEmpty ? cleaned : name;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? AppColors.darkSurfaceCard : Colors.white;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final PathwayModel mod = widget.module;
    final double rawPrice = mod.price > 0 ? mod.price : 0.84;
    final int priceCoins = (rawPrice * 100).round();
    final bool hasSufficientCoins = _walletBalance >= priceCoins;
    final int missingCoins = priceCoins - _walletBalance;
    final List<String> stack =
        mod.stack.isNotEmpty ? mod.stack : <String>[mod.language];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
              blurRadius: 32.0,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  width: 38.0,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3.0),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(22.0, 6.0, 16.0, 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 38.0,
                            height: 38.0,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              size: 18.0,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 12.0),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Unlock Coding Challenges',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  'Full access to all algorithmic benchmarks',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20.0),
                      color: textSecondary,
                    ),
                  ],
                ),
              ),

              Divider(height: 1.0, thickness: 1.0, color: borderColor),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Module Summary Banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurfaceCard,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: <Widget>[
                            LanguageAvatarStack(
                              languages: stack,
                              size: 28.0,
                            ),
                            const SizedBox(width: 12.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    mod.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2.0),
                                  Row(
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          'by ${_cleanCoachName(mod.coachName)}',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w500,
                                            color: textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 13.5,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        mod.rating.toStringAsFixed(1),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14.0),


                      // What's Included Card
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.6)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              "WHAT'S INCLUDED",
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.0,
                                fontWeight: FontWeight.w800,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10.0),
                            _buildPerkRow(
                              'Full access to all coding challenges in this module',
                              textPrimary,
                            ),
                            const SizedBox(height: 6.0),
                            _buildPerkRow(
                              'Automated test suite execution & instant feedback',
                              textPrimary,
                            ),
                            const SizedBox(height: 6.0),
                            _buildPerkRow(
                              'Challenge completion credit & progress tracking',
                              textPrimary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // Transaction / Wallet Receipt Card (1:1 Web Parity)
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface.withValues(alpha: 0.7)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: <Widget>[
                            // Price Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Unlock Price',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                                Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.monetization_on_rounded,
                                      size: 14.0,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '$priceCoins CodeCoins',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      '(${CurrencyFormatter.formatConvertedPhp(rawPrice)})',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),

                            // Balance Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(
                                  'Your Balance',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    color: textSecondary,
                                  ),
                                ),
                                _isLoadingWallet
                                    ? const SizedBox(
                                        width: 14.0,
                                        height: 14.0,
                                        child: CircularProgressIndicator(strokeWidth: 2.0),
                                      )
                                    : Row(
                                        children: <Widget>[
                                          const Icon(
                                            Icons.account_balance_wallet_rounded,
                                            size: 13.0,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            '$_walletBalance CodeCoins',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w600,
                                              color: textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(
                                height: 1.0,
                                thickness: 1.0,
                                color: borderColor,
                              ),
                            ),

                            // Balance Outcome / Shortfall
                            hasSufficientCoins
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Text(
                                        'Balance After',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.0,
                                          color: textSecondary,
                                        ),
                                      ),
                                      Text(
                                        '${_walletBalance - priceCoins} CodeCoins',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            size: 14.0,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            'Need $missingCoins more CodeCoins',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFF59E0B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Low Balance',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(22.0, 14.0, 22.0, 16.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurfaceCard,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: SizedBox(
                        height: 48.0,
                        child: ElevatedButton(
                          onPressed: (_isSubmitting || !hasSufficientCoins)
                              ? null
                              : () => _handleUnlock(priceCoins),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: isDark
                                ? AppColors.onPrimaryDark
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.0),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20.0,
                                  height: 20.0,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.0,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    const Icon(
                                      Icons.lock_open_rounded,
                                      size: 15.0,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Text(
                                      hasSufficientCoins
                                          ? 'Unlock Challenges ($priceCoins Coins)'
                                          : 'Need $missingCoins More Coins',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6.0),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15.0,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerkRow(String text, Color textPrimary) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(
          Icons.check_circle_rounded,
          size: 14.0,
          color: Color(0xFF10B981),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
