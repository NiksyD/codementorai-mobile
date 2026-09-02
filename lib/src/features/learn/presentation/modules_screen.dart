import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../common_widgets/language_avatar_stack.dart';
import '../../../constants/app_colors.dart';
import '../data/pathway_repository.dart';
import '../data/supabase_pathway_repository.dart';
import '../domain/pathway_model.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({
    super.key,
    this.pathwayRepository = const SupabasePathwayRepository(),
  });

  final PathwayRepository pathwayRepository;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  String _selectedCategory = 'all';
  String _searchQuery = '';
  List<PathwayModel> _modules = <PathwayModel>[];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  static const List<Map<String, String>> _categories = <Map<String, String>>[
    <String, String>{'id': 'all', 'label': 'All'},
    <String, String>{'id': 'in-progress', 'label': 'In Progress'},
    <String, String>{'id': 'bookmarked', 'label': 'Saved'},
    <String, String>{'id': 'completed', 'label': 'Completed'},
  ];

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadModules() async {
    final data = await widget.pathwayRepository.getLearnDashboardData('');
    if (mounted) {
      setState(() {
        _modules = data.enrolledPathways;
        _isLoading = false;
      });
    }
  }

  List<PathwayModel> get _filteredModules {
    return _modules.filter((PathwayModel p) {
      final bool matchesCategory = _selectedCategory == 'all' ||
          (_selectedCategory == 'in-progress' &&
              p.status == 'In Progress') ||
          (_selectedCategory == 'completed' && p.status == 'Mastered') ||
          (_selectedCategory == 'bookmarked' && p.completion > 0);

      final bool matchesSearch = _searchQuery.isEmpty ||
          p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.stack.any(
            (String s) => s.toLowerCase().contains(_searchQuery.toLowerCase()),
          );

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final List<PathwayModel> filtered = _filteredModules;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadModules,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: <Widget>[
              // Header & Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Explore Modules',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22.0,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Browse coding modules and practice challenges.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.0,
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16.0),

                      // 1. Redesigned Search Input (Pixel-Perfect Alignment)
                      TextField(
                        controller: _searchController,
                        onChanged: (String val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        textAlignVertical: TextAlignVertical.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurfaceCard
                              : AppColors.lightSurfaceCard,
                          hintText: 'Search modules by tech or name...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w400,
                            color: textSecondary.withValues(alpha: 0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 19.0,
                            color: textSecondary,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18.0,
                                    color: textSecondary,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14.0,
                            vertical: 12.0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14.0),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14.0),

                      // 2. Redesigned Category Pills (Pixel-Perfect Vertical Centering)
                      SizedBox(
                        height: 36.0,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8.0),
                          itemBuilder: (context, index) {
                            final Map<String, String> cat = _categories[index];
                            final bool isSelected =
                                _selectedCategory == cat['id'];

                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedCategory = cat['id']!;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkSurfaceCard
                                          : AppColors.lightSurfaceCard),
                                  borderRadius: BorderRadius.circular(10.0),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark
                                            ? AppColors.darkBorder
                                            : AppColors.lightBorder),
                                  ),
                                ),
                                child: Text(
                                  cat['label']!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.0,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? (isDark
                                            ? AppColors.onPrimaryDark
                                            : Colors.white)
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],
                  ),
                ),
              ),

              // Modules List
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.layers_clear_outlined,
                          size: 48.0,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          'No modules found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Try searching for another keyword or filter.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.0,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 32.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final PathwayModel module = filtered[index];
                        return _buildModuleCard(
                          context: context,
                          module: module,
                          isDark: isDark,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required PathwayModel module,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Stack + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              LanguageAvatarStack(
                languages: module.stack.isNotEmpty
                    ? module.stack
                    : <String>[module.language],
                size: 26.0,
              ),
              Text(
                '${module.completion}% Complete',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: module.completion > 0
                      ? AppColors.primary
                      : textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),

          // Title & Description
          Text(
            module.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15.0,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            module.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.0,
              color: textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14.0),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: LinearProgressIndicator(
              value: (module.completion / 100.0).clamp(0.0, 1.0),
              minHeight: 5.0,
              backgroundColor:
                  isDark ? AppColors.darkBorder : AppColors.lightBorder,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 14.0),

          // Footer: Coach info + Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '${module.totalModules} Topics · ${module.coachName ?? 'CodeMentor AI'}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.0,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor:
                      isDark ? AppColors.onPrimaryDark : Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14.0,
                    vertical: 8.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  module.completion > 0 ? 'Continue' : 'Start',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension IterableExtension<E> on Iterable<E> {
  Iterable<E> filter(bool Function(E element) test) sync* {
    for (final E element in this) {
      if (test(element)) {
        yield element;
      }
    }
  }
}
