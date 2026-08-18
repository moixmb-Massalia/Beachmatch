import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/colors.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'community_screen.dart';
import 'messages_screen.dart';
import 'tournaments/tournament_list_screen.dart';
import 'profile_screen.dart';
import 'tutorial_screen.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  const MainNavigationScreen({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  Stream<int>? _unreadCountStream;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser != null && _unreadCountStream == null) {
      _unreadCountStream = ChatService().getUnreadCount(currentUser.id);
    } else if (currentUser == null) {
      _unreadCountStream = null;
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const MapScreen(),
    const CommunityScreen(),
    const TournamentListScreen(),
    const MessagesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;
    if (currentUser != null && !currentUser.hasSeenTutorial) {
      return const TutorialScreen();
    }

    return Scaffold(
      extendBody: true, // Body flows behind the bottom nav bar
      body: _screens[_currentIndex],
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildNavItem(0, CupertinoIcons.home, CupertinoIcons.house_fill, AppLocalizations.of(context)!.navHome),
                      _buildNavItem(1, CupertinoIcons.map, CupertinoIcons.map_fill, AppLocalizations.of(context)!.navCourts),
                      _buildNavItem(2, CupertinoIcons.person_3, CupertinoIcons.person_3_fill, "Clubs"),
                      _buildNavItem(3, CupertinoIcons.star, CupertinoIcons.star_fill, AppLocalizations.of(context)!.navTournaments),
                      StreamBuilder<int>(
                        stream: _unreadCountStream ?? const Stream.empty(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data ?? 0;
                          return _buildNavItem(
                            4,
                            CupertinoIcons.chat_bubble_2,
                            CupertinoIcons.chat_bubble_2_fill,
                            AppLocalizations.of(context)!.navChat,
                            badgeCount: unreadCount,
                          );
                        },
                      ),
                      _buildNavItem(5, CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill, AppLocalizations.of(context)!.navProfile),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 12 : 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? Border.all(color: AppColors.coral.withOpacity(0.5), width: 1) : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey<bool>(isSelected),
                    color: isSelected ? AppColors.gold : Colors.white70,
                    size: isSelected ? 24 : 22,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
