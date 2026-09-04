import '../../services/revenue_cat_service.dart';

enum AppTier { free, pro }

enum FeatureType {
  unlimitedSnippets,
  dynamicInputPrompts,
  customCategories,
  encryptedJsonBackupRestore,
  quickAccessNotificationDock,
}

class FeatureManager {
  static const int freeSnippetLimit = 15;
  static const List<String> freeCategories = ['All', 'Work', 'Personal'];

  /// Checks if current user is Pro via RevenueCat entitlement status
  static Future<bool> isPro() async {
    return await RevenueCatService.isProUser();
  }

  /// Centralized gate to verify if a feature is unlocked for the active tier
  static Future<bool> canAccessFeature(FeatureType feature) async {
    final proStatus = await isPro();
    if (proStatus) return true;

    switch (feature) {
      case FeatureType.unlimitedSnippets:
      case FeatureType.dynamicInputPrompts:
      case FeatureType.customCategories:
      case FeatureType.encryptedJsonBackupRestore:
      case FeatureType.quickAccessNotificationDock:
        return false;
    }
  }

  /// Checks snippet creation limit for free tier
  static Future<bool> canCreateSnippet(int currentCount) async {
    final proStatus = await isPro();
    if (proStatus) return true;
    return currentCount < freeSnippetLimit;
  }

  /// Checks category creation/filtering permissions
  static Future<bool> canUseCategory(String category) async {
    final proStatus = await isPro();
    if (proStatus) return true;
    return freeCategories.contains(category);
  }
}
