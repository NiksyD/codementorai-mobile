import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedTier = 'free'; // 'free' or 'pro'
  bool _isSubmitting = false;

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
    final double proPrice = mod.price > 0 ? mod.price : 19.0;
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Enroll in Module',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Text(
                          'Select your learning plan to get started',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20.0),
                      color: textSecondary,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1.0),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22.0),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Module Summary Banner
                      Container(
                        padding: const EdgeInsets.all(14.0),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.lightSurfaceCard,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: <Widget>[
                            LanguageAvatarStack(
                              languages: stack,
                              size: 32.0,
                            ),
                            const SizedBox(width: 14.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    mod.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3.0),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        'by ${mod.coachName ?? 'CodeMentor AI'}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 8.0),
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14.0,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 2.0),
                                      Text(
                                        mod.rating.toStringAsFixed(1),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11.0,
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
                      const SizedBox(height: 18.0),

                      // Plan 1: Free Guided Practice
                      _buildPlanCard(
                        id: 'free',
                        title: 'Guided Practice',
                        price: 'Free',
                        description:
                            'Core curriculum with structured guided exercises and daily AI hints.',
                        perks: const <String>[
                          'Guided Lessons & Sandbox',
                          '5 Daily AI Mentor Hints',
                          'Progress & Streak Tracking',
                        ],
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                      const SizedBox(height: 12.0),

                      // Plan 2: Complete Mastery Pro
                      _buildPlanCard(
                        id: 'pro',
                        title: 'Complete Mastery',
                        price: CurrencyFormatter.formatConvertedPhp(proPrice),
                        subPrice: '≈ \$${proPrice.toStringAsFixed(0)} USD',
                        badge: 'RECOMMENDED',
                        description:
                            'Unlock algorithmic challenges, unlimited AI code reviews, and certification.',
                        perks: const <String>[
                          'All Algorithmic Challenges',
                          'Unlimited AI Code Reviews',
                          'Verified Certificate of Completion',
                        ],
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
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
                      ? const Color(0xFF131927)
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
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  final NavigatorState navigator =
                                      Navigator.of(context);
                                  HapticFeedback.mediumImpact();
                                  setState(() {
                                    _isSubmitting = true;
                                  });
                                  await widget.onEnroll(_selectedTier);
                                  navigator.pop();
                                },
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
                                    Text(
                                      _selectedTier == 'pro'
                                          ? 'Upgrade & Enroll • ${CurrencyFormatter.formatConvertedPhp(proPrice)}'
                                          : 'Enroll for Free',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 6.0),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 16.0,
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

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    String? subPrice,
    required String description,
    required List<String> perks,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    String? badge,
  }) {
    final bool isSelected = _selectedTier == id;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedTier = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(15.0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08)
              : (isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.6)
                  : Colors.white),
          borderRadius: BorderRadius.circular(18.0),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 18.0,
                      height: 18.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : textSecondary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 12.0,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10.0),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6.0,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.0,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      price,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if (subPrice != null) ...<Widget>[
                      const SizedBox(height: 1.0),
                      Text(
                        subPrice,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.0,
                          color: textSecondary.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6.0),
            Padding(
              padding: const EdgeInsets.only(left: 28.0),
              child: Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.0,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            Padding(
              padding: const EdgeInsets.only(left: 28.0),
              child: Column(
                children: perks.map((String perk) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14.0,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          perk,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
