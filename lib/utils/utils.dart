class Utils {
  static const Map<String, String> _iconMap = {
    'login': 'assets/icons/login-3.svg',
    'donation': 'assets/icons/money-bag.svg',
    'verified': 'assets/icons/verified-check.svg',
    'award': 'assets/icons/award.svg',
    'welcome': 'assets/icons/hand.svg',
    'info': 'assets/icons/info-square.svg',
  };

  static String getSvgAsset(String name) {
    return _iconMap[name.toLowerCase()] ??
        'assets/icons/default.svg'; // Fallback
  }
}
