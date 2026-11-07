import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common_widgets/app_toast.dart';
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
      builder: (BuildContext ctx) =>
          ModulePreviewSheet(module: module, onEnroll: onEnroll),
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
      AppToast.showError(context, 'Please log in to unlock challenges');
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
        AppToast.showError(context, 'Failed to unlock: $e');
      }
    }
  }

  String _cleanCoachName(String? name) {
    if (name == null || name.trim().isEmpty) return 'CodeMentor AI';
    final String cleaned = name.replaceAll(RegExp(r'TEST\d*'), '').trim();
    return cleaned.isNotEmpty ? cleaned : name;
  }

  Widget _row(
    String label,
    Widget value,
    Color textSecondary,
    Color borderColor,
  ) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48.0),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.0,
              color: textSecondary,
            ),
          ),
          value,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    final PathwayModel mod = widget.module;
    final double rawPrice = mod.price > 0 ? mod.price : 0.84;
    final int priceCoins = CurrencyFormatter.coinsFromUsd(rawPrice);
    // Not known until the wallet has loaded, so the button stays off until then.
    final bool hasSufficientCoins =
        !_isLoadingWallet && _walletBalance >= priceCoins;
    final int missingCoins = priceCoins - _walletBalance;
    final List<String> stack = mod.stack.isNotEmpty
        ? mod.stack
        : <String>[mod.language];

    TextStyle mono({FontWeight w = FontWeight.w600}) =>
        GoogleFonts.jetBrainsMono(
          fontSize: 13.0,
          fontWeight: w,
          color: textPrimary,
        );

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 4.0, 8.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Unlock Coding Challenges',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'Full access to all algorithmic benchmarks in this module',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 22.0),
                    color: textSecondary,
                  ),
                ],
              ),
            ),
            Divider(height: 1.0, thickness: 1.0, color: borderColor),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        LanguageAvatarStack(
                          languages: stack,
                          size: 26.0,
                          borderColor: bgColor,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                mod.title,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text.rich(
                                TextSpan(
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text:
                                          'by ${_cleanCoachName(mod.coachName)}  ·  ★ ',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.0,
                                        color: textSecondary,
                                      ),
                                    ),
                                    TextSpan(
                                      text: mod.rating.toStringAsFixed(1),
                                      style: GoogleFonts.jetBrainsMono(
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
                      ],
                    ),
                    const SizedBox(height: 20.0),
                    Text(
                      "What's included",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    _buildPerkRow(
                      'Full access to all coding challenges in this module',
                      textPrimary,
                      textSecondary,
                    ),
                    _buildPerkRow(
                      'Automated test runs with instant feedback',
                      textPrimary,
                      textSecondary,
                    ),
                    _buildPerkRow(
                      'Challenge completion credit and progress tracking',
                      textPrimary,
                      textSecondary,
                    ),
                    const SizedBox(height: 16.0),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Column(
                        children: <Widget>[
                          _row(
                            'Unlock price',
                            Text.rich(
                              TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: '$priceCoins coins',
                                    style: mono(w: FontWeight.w700),
                                  ),
                                  TextSpan(
                                    text:
                                        '  ${CurrencyFormatter.formatConvertedPhp(rawPrice)}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.0,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            textSecondary,
                            borderColor,
                          ),
                          _row(
                            'Your balance',
                            _isLoadingWallet
                                ? Text('—', style: mono())
                                : Text('$_walletBalance coins', style: mono()),
                            textSecondary,
                            borderColor,
                          ),
                          _row(
                            _isLoadingWallet || hasSufficientCoins
                                ? 'Balance after unlocking'
                                : 'Short by',
                            _isLoadingWallet
                                ? Text('—', style: mono())
                                : hasSufficientCoins
                                ? Text(
                                    '${_walletBalance - priceCoins} coins',
                                    style: mono(),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16.0,
                                        color: textPrimary,
                                      ),
                                      const SizedBox(width: 4.0),
                                      Text(
                                        '$missingCoins coins',
                                        style: mono(),
                                      ),
                                    ],
                                  ),
                            textSecondary,
                            borderColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 12.0),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64.0, 48.0),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.0,
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20.0,
                                height: 20.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const Icon(
                                    Icons.lock_open_rounded,
                                    size: 18.0,
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    _isLoadingWallet
                                        ? 'Checking balance'
                                        : hasSufficientCoins
                                        ? 'Unlock for $priceCoins coins'
                                        : 'Need $missingCoins more coins',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.0,
                                      fontWeight: FontWeight.w700,
                                    ),
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
    );
  }

  Widget _buildPerkRow(String text, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 18.0, color: textSecondary),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
