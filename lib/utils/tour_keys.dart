import 'package:flutter/widgets.dart';

/// One GlobalKey per thing the guided tour ever points at — kept in one
/// place so every screen imports the same keys instead of inventing its own.
class TourKeys {
  TourKeys._();

  // Home
  static final greeting = GlobalKey(debugLabel: 'tour.greeting');
  static final quickActions = GlobalKey(debugLabel: 'tour.quickActions');
  static final demandStatus = GlobalKey(debugLabel: 'tour.demandStatus');
  static final monthTimeline = GlobalKey(debugLabel: 'tour.monthTimeline');
  static final balanceSnapshot = GlobalKey(debugLabel: 'tour.balanceSnapshot');

  // Bottom navigation (whole bar, not individual icons — measuring internal
  // NavigationDestination positions isn't reliable across Flutter versions).
  static final navBar = GlobalKey(debugLabel: 'tour.navBar');

  // Place Demand
  static final demandSearch = GlobalKey(debugLabel: 'tour.demandSearch');
  static final demandBalanceBar = GlobalKey(debugLabel: 'tour.demandBalanceBar');
  static final demandCategories = GlobalKey(debugLabel: 'tour.demandCategories');

  // Balance
  static final balanceModeSwitch = GlobalKey(debugLabel: 'tour.balanceModeSwitch');
  static final balanceSummary = GlobalKey(debugLabel: 'tour.balanceSummary');
  static final balanceCategoryToggle = GlobalKey(debugLabel: 'tour.balanceCategoryToggle');

  // History
  static final historyList = GlobalKey(debugLabel: 'tour.historyList');

  // Profile
  static final profileCard = GlobalKey(debugLabel: 'tour.profileCard');
  static final profileDarkMode = GlobalKey(debugLabel: 'tour.profileDarkMode');
  static final profileReplayTour = GlobalKey(debugLabel: 'tour.profileReplayTour');
}
