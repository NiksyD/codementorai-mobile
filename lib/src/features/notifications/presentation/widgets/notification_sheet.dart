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
  String _filter = 'all'; // 'all' or 'unread'

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
    final List<NotificationModel> list =
        await widget.repository.getNotifications(widget.userId);
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
      _items = _items.map((NotificationModel n) => n.copyWith(isRead: true)).toList();
    });
    widget.onChanged?.call();

    await widget.repository.markAllAsRead(widget.userId);
  }

  Future<void> _handleClearAll() async {
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
    final Color backgroundColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color cardColor =
        isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard;
    final Color borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final int unreadCount = _items.where((NotificationModel n) => !n.isRead).length;
    final List<NotificationModel> filtered = _filter == 'unread'
        ? _items.where((NotificationModel n) => !n.isRead).toList()
        : _items;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 1. Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),

            // 2. Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 4.0, 16.0, 12.0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Text(
                          'Notifications',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17.0,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '$unreadCount new',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Mark All Read Button
                  if (unreadCount > 0)
                    IconButton(
                      icon: const Icon(Icons.done_all_rounded, size: 20.0),
                      color: AppColors.primary,
                      tooltip: 'Mark all as read',
                      onPressed: _handleMarkAllAsRead,
                    ),

                  // Clear All Button (if list has items)
                  if (_items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 20.0),
                      color: textSecondary,
                      tooltip: 'Clear notifications',
                      onPressed: _handleClearAll,
                    ),

                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20.0),
                    color: textSecondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 3. Filter Segmented Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Row(
                children: <Widget>[
                  _buildFilterTab(
                    id: 'all',
                    label: 'All',
                    count: _items.length,
                    isSelected: _filter == 'all',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(width: 8.0),
                  _buildFilterTab(
                    id: 'unread',
                    label: 'Unread',
                    count: unreadCount,
                    isSelected: _filter == 'unread',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8.0),
            const Divider(height: 1.0, thickness: 0.8),

            // 4. Notification List Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : filtered.isEmpty
                      ? _buildEmptyState(textPrimary, textSecondary)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          physics: const BouncingScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext ctx, int i) =>
                              const SizedBox(height: 8.0),
                          itemBuilder: (BuildContext ctx, int i) {
                            final NotificationModel item = filtered[i];
                            return _buildNotificationItem(
                              item: item,
                              isDark: isDark,
                              cardColor: cardColor,
                              borderColor: borderColor,
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

  Widget _buildFilterTab({
    required String id,
    required String label,
    required int count,
    required bool isSelected,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _filter = id);
      },
      borderRadius: BorderRadius.circular(10.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : cardColor,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: isSelected ? AppColors.primary : borderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.onPrimaryDark : textSecondary,
              ),
            ),
            const SizedBox(width: 6.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.onPrimaryDark.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.onPrimaryDark : textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem({
    required NotificationModel item,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final (IconData icon, Color iconColor) = _getTypeStyle(item.type);

    return InkWell(
      onTap: () => _handleNavigate(item),
      borderRadius: BorderRadius.circular(14.0),
      child: Container(
        padding: const EdgeInsets.all(14.0),
        decoration: BoxDecoration(
          color: item.isRead
              ? cardColor.withValues(alpha: 0.4)
              : cardColor,
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: item.isRead
                ? borderColor.withValues(alpha: 0.5)
                : AppColors.primary.withValues(alpha: 0.35),
            width: item.isRead ? 0.8 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Type Icon
            Container(
              width: 36.0,
              height: 36.0,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, size: 18.0, color: iconColor),
            ),
            const SizedBox(width: 12.0),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight:
                                item.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.0,
                          color: textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                      if (!item.isRead) ...<Widget>[
                        const SizedBox(width: 6.0),
                        Container(
                          width: 7.0,
                          height: 7.0,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3.0),
                  Text(
                    item.message,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: textSecondary,
                      height: 1.35,
                    ),
                  ),

                  // Action Deep Link Pill
                  if (item.actionText != null && item.actionText!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8.0),
                    Row(
                      children: <Widget>[
                        Text(
                          item.actionText!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 12.0,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _getTypeStyle(String type) {
    switch (type) {
      case 'ai':
        return (Icons.auto_awesome_rounded, AppColors.primary);
      case 'streak':
        return (Icons.local_fire_department_rounded, const Color(0xFFF59E0B));
      case 'report':
        return (Icons.flag_rounded, const Color(0xFFF43F5E));
      case 'achievement':
        return (Icons.emoji_events_rounded, const Color(0xFFA855F7));
      default:
        return (Icons.info_outline_rounded, const Color(0xFF64748B));
    }
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.notifications_none_rounded,
              size: 44.0,
              color: textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12.0),
            Text(
              'No notifications',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14.0,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              _filter == 'unread'
                  ? 'You\'re caught up on all new alerts.'
                  : 'Activity updates and AI reviews will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.0,
                color: textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
