import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../constants/app_colors.dart';
import '../../data/notification_repository.dart';
import '../../domain/notification_model.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({
    super.key,
    required this.userId,
    required this.repository,
    this.initialNotifications,
    this.onChanged,
  });

  final String userId;
  final NotificationRepository repository;
  final List<NotificationModel>? initialNotifications;
  final VoidCallback? onChanged;

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required NotificationRepository repository,
    List<NotificationModel>? initialNotifications,
    VoidCallback? onChanged,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => NotificationSheet(
        userId: userId,
        repository: repository,
        initialNotifications: initialNotifications,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  List<NotificationModel> _items = <NotificationModel>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialNotifications != null) {
      _items = List<NotificationModel>.from(widget.initialNotifications!);
      _isLoading = false;
    }
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final List<NotificationModel> list = await widget.repository
        .getNotifications(widget.userId);
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMarkAsRead(NotificationModel item) async {
    if (item.isRead) return;

    HapticFeedback.selectionClick();
    setState(() {
      _items = _items.map((NotificationModel n) {
        return n.id == item.id ? n.copyWith(isRead: true) : n;
      }).toList();
    });
    widget.onChanged?.call();

    await widget.repository.markAsRead(item.id, widget.userId);
  }

  Future<void> _handleMarkAllAsRead() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _items = _items
          .map((NotificationModel n) => n.copyWith(isRead: true))
          .toList();
    });
    widget.onChanged?.call();

    await widget.repository.markAllAsRead(widget.userId);
  }

  Future<void> _handleClearAll() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            title: const Text('Clear all notifications?'),
            content: const Text(
              'This removes every notification and cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Clear all'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _items = <NotificationModel>[];
    });
    widget.onChanged?.call();

    await widget.repository.clearAll(widget.userId);
  }

  void _handleNavigate(NotificationModel item) async {
    await _handleMarkAsRead(item);
    if (!mounted) return;

    Navigator.of(context).pop();

    if (item.actionUrl != null && item.actionUrl!.isNotEmpty) {
      context.push(item.actionUrl!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;
    final Color borderColor = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;
    final Color textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final Color textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final int unreadCount = _items
        .where((NotificationModel n) => !n.isRead)
        .length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
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

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 4.0, 0.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    constraints: const BoxConstraints(
                      minWidth: 48.0,
                      minHeight: 48.0,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 22.0),
                    color: textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Count on the left, plain text actions on the right
            if (_items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 0.0, 8.0, 0.0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: '$unreadCount',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12.0,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: ' unread',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.0,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      _textAction(
                        'Mark all read',
                        textSecondary,
                        _handleMarkAllAsRead,
                      ),
                    _textAction('Clear all', textSecondary, _handleClearAll),
                  ],
                ),
              ),

            Divider(height: 1.0, thickness: 1.0, color: borderColor),

            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2.0,
                        ),
                      ),
                    )
                  : _items.isEmpty
                  ? _buildEmptyState(textPrimary, textSecondary)
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _items.length,
                      separatorBuilder: (BuildContext ctx, int i) => Divider(
                        height: 1.0,
                        thickness: 1.0,
                        indent: 20.0,
                        endIndent: 20.0,
                        color: borderColor,
                      ),
                      itemBuilder: (BuildContext ctx, int i) {
                        return _buildNotificationItem(
                          item: _items[i],
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textAction(String label, Color color, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48.0, 48.0),
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        foregroundColor: color,
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12.0,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required NotificationModel item,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Semantics(
      button: true,
      label:
          '${item.isRead ? '' : 'Unread. '}${item.title}. ${item.message}. ${item.timeAgo}',
      child: InkWell(
        onTap: () => _handleNavigate(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1.0),
                child: Icon(
                  _getTypeIcon(item.type, item.title),
                  size: 20.0,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            item.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.0,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: textPrimary,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Text(
                          item.timeAgo,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      item.message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.0,
                        color: textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...<Widget>[
                const SizedBox(width: 10.0),
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Container(
                    width: 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: textPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// One neutral icon per kind of notification. Unread is shown by bold text and a dot, not colour.
  IconData _getTypeIcon(String type, [String? title]) {
    final String lowerTitle = (title ?? '').toLowerCase();
    if (lowerTitle.contains('invitation') || lowerTitle.contains('invite')) {
      return Icons.mail_outline_rounded;
    }
    switch (type) {
      case 'room_member':
      case 'hub_member':
        return Icons.school_outlined;
      case 'room_submission':
      case 'hub_submission':
        return Icons.code_rounded;
      case 'ai':
        return Icons.rate_review_outlined;
      case 'streak':
        return Icons.local_fire_department_outlined;
      case 'achievement':
        return Icons.check_circle_outline_rounded;
      case 'assessment':
        return Icons.timer_outlined;
      case 'report':
        return Icons.flag_outlined;
      case 'revenue':
        return Icons.monetization_on_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 56.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'No notifications yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.0,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              'Updates on your submissions, hubs and streak will show up here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.0,
                color: textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
