import 'package:flutter/material.dart';

import 'app_prefs.dart';
import 'tour_keys.dart';

/// One stop on the guided tour: what to highlight (or nothing, for a plain
/// intro/outro slide), which tab it lives on, and a short mentor-style note.
class TourStep {
  final GlobalKey? targetKey;
  final int tabIndex; // -1 = stay on the current tab
  final String title;
  final String description;
  final IconData icon;
  const TourStep({
    this.targetKey,
    this.tabIndex = -1,
    required this.title,
    required this.description,
    this.icon = Icons.info_outline_rounded,
  });
}

/// Whether the customer has already completed (or skipped) the tour once.
/// Auto-start reads this; "Replay tour" on Profile ignores it.
class TourPrefs {
  TourPrefs._();
  static const _key = 'app_tour_seen_v1';
  static bool get seen => AppPrefs.getString(_key) == '1';
  static void markSeen() => AppPrefs.setString(_key, '1');
}

/// Drives the spotlight overlay: which step is current, and — when a step
/// belongs to a different tab — asks the shell to switch there first.
class TourController extends ChangeNotifier {
  List<TourStep> _steps = const [];
  int _index = -1;

  /// Set by the shell so the controller can bring the right tab into view.
  void Function(int tabIndex)? onSwitchTab;

  bool get isActive => _index >= 0 && _index < _steps.length;
  int get index => _index;
  int get total => _steps.length;
  TourStep? get current => isActive ? _steps[_index] : null;
  bool get isFirst => _index <= 0;
  bool get isLast => _index >= _steps.length - 1;

  void start(List<TourStep> steps) {
    if (steps.isEmpty) return;
    _steps = steps;
    _index = 0;
    _goToStepTab();
    notifyListeners();
  }

  void next() {
    if (!isActive) return;
    if (isLast) {
      finish();
      return;
    }
    _index++;
    _goToStepTab();
    notifyListeners();
  }

  void back() {
    if (!isActive || isFirst) return;
    _index--;
    _goToStepTab();
    notifyListeners();
  }

  void skip() => finish();

  void finish() {
    _index = -1;
    TourPrefs.markSeen();
    notifyListeners();
  }

  void _goToStepTab() {
    final s = current;
    if (s != null && s.tabIndex >= 0) onSwitchTab?.call(s.tabIndex);
  }
}

/// The full guided tour, start to finish — Home through Profile. Every line
/// is short on purpose: this is a quick orientation, not a manual.
List<TourStep> buildAppTour() => [
      const TourStep(
        title: 'Welcome to StockFlow',
        description: 'A minute-long look around — skip anytime, or replay it later from Profile.',
        icon: Icons.waving_hand_rounded,
      ),
      TourStep(
        targetKey: TourKeys.greeting,
        tabIndex: 0,
        title: 'Home',
        description: 'Always shows today\'s date and what\'s active right now.',
        icon: Icons.home_rounded,
      ),
      TourStep(
        targetKey: TourKeys.quickActions,
        tabIndex: 0,
        title: 'Quick actions',
        description: 'One tap to place a demand, check your balance, or see past orders.',
        icon: Icons.touch_app_rounded,
      ),
      TourStep(
        targetKey: TourKeys.demandStatus,
        tabIndex: 0,
        title: 'Demand window',
        description: 'Shows whether a demand is open, which week, and exactly when it closes.',
        icon: Icons.event_available_rounded,
      ),
      TourStep(
        targetKey: TourKeys.monthTimeline,
        tabIndex: 0,
        title: 'This month at a glance',
        description: 'Every week of the month — done, active, or still upcoming.',
        icon: Icons.calendar_view_week_rounded,
      ),
      TourStep(
        targetKey: TourKeys.balanceSnapshot,
        tabIndex: 0,
        title: 'Your balance',
        description: 'What\'s left of your entitlement this month. Tap it for the full breakdown.',
        icon: Icons.account_balance_wallet_rounded,
      ),
      TourStep(
        targetKey: TourKeys.navBar,
        tabIndex: 0,
        title: 'Get around',
        description: 'Home, Demand, Balance, History and Profile — always one tap away.',
        icon: Icons.apps_rounded,
      ),
      TourStep(
        targetKey: TourKeys.demandSearch,
        tabIndex: 1,
        title: 'Place Demand',
        description: 'Search for any item, or browse by category below.',
        icon: Icons.search_rounded,
      ),
      TourStep(
        targetKey: TourKeys.demandBalanceBar,
        tabIndex: 1,
        title: 'Your balance, live',
        description: 'Updates as you add items — you can never add more than what\'s left.',
        icon: Icons.speed_rounded,
      ),
      TourStep(
        targetKey: TourKeys.balanceModeSwitch,
        tabIndex: 2,
        title: 'Balance tab',
        description: 'Switch between this week, a previous week, or your full history.',
        icon: Icons.tune_rounded,
      ),
      TourStep(
        targetKey: TourKeys.balanceSummary,
        tabIndex: 2,
        title: 'Three numbers',
        description: 'Entitlement, used, and remaining — always shown the same way.',
        icon: Icons.summarize_rounded,
      ),
      TourStep(
        targetKey: TourKeys.balanceCategoryToggle,
        tabIndex: 2,
        title: 'By category',
        description: 'Tap any category to see exactly how that number was calculated.',
        icon: Icons.category_rounded,
      ),
      TourStep(
        targetKey: TourKeys.historyList,
        tabIndex: 3,
        title: 'My Order History',
        description: 'Every demand you\'ve placed, with its full status timeline. Tap one for details.',
        icon: Icons.history_rounded,
      ),
      TourStep(
        targetKey: TourKeys.profileCard,
        tabIndex: 4,
        title: 'Profile',
        description: 'Your details, and where to sign out when you need to.',
        icon: Icons.person_rounded,
      ),
      TourStep(
        targetKey: TourKeys.profileDarkMode,
        tabIndex: 4,
        title: 'Light or dark',
        description: 'Switch the whole app to whatever\'s easier on your eyes.',
        icon: Icons.dark_mode_rounded,
      ),
      const TourStep(
        title: 'You\'re all set',
        description: 'That\'s StockFlow. Replay this tour anytime from your Profile.',
        icon: Icons.check_circle_rounded,
      ),
    ];
