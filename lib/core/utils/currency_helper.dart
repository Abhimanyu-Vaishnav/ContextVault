import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';

class RegionalPrice {
  final String monthlyPrice;
  final String annualPrice;
  final String annualPricePerMonth;
  final String currencySymbol;
  final int savingsPercentage;

  const RegionalPrice({
    required this.monthlyPrice,
    required this.annualPrice,
    required this.annualPricePerMonth,
    required this.currencySymbol,
    required this.savingsPercentage,
  });
}

class CurrencyHelper {
  /// Resolves regional fallback pricing based on device locale when RevenueCat packages are offline/unavailable.
  /// Uses View context, PlatformDispatcher, and Platform.localeName checks.
  static RegionalPrice getRegionalPrice([BuildContext? context]) {
    try {
      List<Locale> locales = [];

      if (context != null) {
        try {
          locales.add(View.of(context).platformDispatcher.locale);
        } catch (_) {}
      }

      locales.add(PlatformDispatcher.instance.locale);
      locales.addAll(PlatformDispatcher.instance.locales);

      String platformLocale = '';
      try {
        platformLocale = Platform.localeName.toLowerCase();
      } catch (_) {}

      bool isIndia = false;

      // Check all resolved locales
      for (final l in locales) {
        final country = l.countryCode?.toUpperCase() ?? '';
        final lang = l.languageCode.toLowerCase();
        final str = l.toString().toLowerCase();

        if (country == 'IN' || lang == 'hi' || str.contains('in') || str.contains('hi')) {
          isIndia = true;
          break;
        }
      }

      if (!isIndia && (platformLocale.contains('in') || platformLocale.contains('hi'))) {
        isIndia = true;
      }

      // 1. India (INR) Force ₹299 / mo & ₹1,999 / yr (~₹166/mo — Save 45%)
      if (isIndia) {
        return const RegionalPrice(
          monthlyPrice: '₹299',
          annualPrice: '₹1,999',
          annualPricePerMonth: '₹166',
          currencySymbol: '₹',
          savingsPercentage: 45,
        );
      }

      // 2. Eurozone (EUR)
      bool isEurozone = false;
      for (final l in locales) {
        final country = l.countryCode?.toUpperCase() ?? '';
        final lang = l.languageCode.toLowerCase();
        if (['DE', 'FR', 'ES', 'IT', 'NL', 'BE', 'AT', 'FI', 'IE', 'PT', 'GR'].contains(country) ||
            ['de', 'fr', 'es', 'it', 'nl', 'pt'].contains(lang)) {
          isEurozone = true;
          break;
        }
      }

      if (isEurozone ||
          platformLocale.contains('de') ||
          platformLocale.contains('fr') ||
          platformLocale.contains('es') ||
          platformLocale.contains('it')) {
        return const RegionalPrice(
          monthlyPrice: '€3.49',
          annualPrice: '€22.99',
          annualPricePerMonth: '€1.91',
          currencySymbol: '€',
          savingsPercentage: 45,
        );
      }

      // 3. United Kingdom (GBP)
      bool isUK = false;
      for (final l in locales) {
        final country = l.countryCode?.toUpperCase() ?? '';
        if (country == 'GB') {
          isUK = true;
          break;
        }
      }
      if (isUK || platformLocale.contains('gb')) {
        return const RegionalPrice(
          monthlyPrice: '£2.99',
          annualPrice: '£19.99',
          annualPricePerMonth: '£1.66',
          currencySymbol: '£',
          savingsPercentage: 44,
        );
      }

      // 4. Default US / International (USD)
      return const RegionalPrice(
        monthlyPrice: '\$3.99',
        annualPrice: '\$24.99',
        annualPricePerMonth: '\$2.08',
        currencySymbol: '\$',
        savingsPercentage: 48,
      );
    } catch (_) {
      // Safe fallback
      return const RegionalPrice(
        monthlyPrice: '₹299',
        annualPrice: '₹1,999',
        annualPricePerMonth: '₹166',
        currencySymbol: '₹',
        savingsPercentage: 45,
      );
    }
  }
}
