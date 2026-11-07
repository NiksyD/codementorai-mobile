import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class SelectOption {
  const SelectOption({
    required this.id,
    required this.label,
    this.count,
    this.leading,
  });

  final String id;
  final String label;
  final int? count;
  final Widget? leading;
}

/// A filter that opens a bottom sheet with every choice visible, the way phone
/// apps do it. The chosen row is bold with a check mark, so the choice never
/// depends on colour.
class SelectFilter extends StatelessWidget {
  const SelectFilter({
    super.key,
    required this.title,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.height = 44.0,
  });

  /// Shown at the top of the sheet, e.g. "Language".
  final String title;
  final List<SelectOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final double height;

  SelectOption get _current => options.firstWhere(
    (SelectOption o) => o.id == selectedId,
    orElse: () => options.first,
  );

  Future<void> _open(BuildContext context) async {
    HapticFeedback.selectionClick();
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) =>
          _SelectSheet(title: title, options: options, selectedId: selectedId),
    );
    if (picked != null && picked != selectedId) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final SelectOption current = _current;
    final bool filtered = current.id != options.first.id;

    return Semantics(
      button: true,
      label: '$title: ${current.label}',
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(10.0),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                current.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.0,
                  fontWeight: filtered ? FontWeight.w700 : FontWeight.w500,
                  color: filtered ? textPrimary : textSecondary,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20.0,
                color: textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectSheet extends StatelessWidget {
  const _SelectSheet({
    required this.title,
    required this.options,
    required this.selectedId,
  });

  final String title;
  final List<SelectOption> options;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 6.0, 20.0, 8.0),
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ),
            Divider(height: 1.0, thickness: 1.0, color: border),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: options.length,
                separatorBuilder: (BuildContext c, int i) => Divider(
                  height: 1.0,
                  thickness: 1.0,
                  indent: 20.0,
                  endIndent: 20.0,
                  color: border,
                ),
                itemBuilder: (BuildContext c, int i) {
                  final SelectOption o = options[i];
                  final bool selected = o.id == selectedId;
                  return Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(o.id),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52.0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: <Widget>[
                              if (o.leading != null) ...<Widget>[
                                o.leading!,
                                const SizedBox(width: 12.0),
                              ],
                              Expanded(
                                child: Text(
                                  o.label,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.0,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              if (o.count != null) ...<Widget>[
                                Text(
                                  '${o.count}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13.0,
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12.0),
                              ],
                              SizedBox(
                                width: 22.0,
                                child: selected
                                    ? Icon(
                                        Icons.check_rounded,
                                        size: 20.0,
                                        color: textPrimary,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
