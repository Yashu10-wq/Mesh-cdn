import 'package:flutter/material.dart';

enum NavPage { overview, networkMap, storageCache, settings }

class AppNavigationProvider extends ChangeNotifier {
  NavPage _currentPage = NavPage.overview;
  NavPage get currentPage => _currentPage;

  void navigate(NavPage page) {
    if (_currentPage == page) return;
    _currentPage = page;
    notifyListeners();
  }
}
