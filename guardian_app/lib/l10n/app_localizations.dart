import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get appTitle;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get homeTitle;

  /// No description provided for @onboardingDisclosureTitle.
  ///
  /// In en, this message translates to:
  /// **'What Guardian needs to protect you'**
  String get onboardingDisclosureTitle;

  /// No description provided for @onboardingDisclosureNeedPaymentAppsBullet1.
  ///
  /// In en, this message translates to:
  /// **'Read screen content in payment apps such as Google Pay, PhonePe, and Paytm to detect risky transactions.'**
  String get onboardingDisclosureNeedPaymentAppsBullet1;

  /// No description provided for @onboardingDisclosureNeedMessagesBullet2.
  ///
  /// In en, this message translates to:
  /// **'Read supported payment-screen details to detect risky payment requests.'**
  String get onboardingDisclosureNeedMessagesBullet2;

  /// No description provided for @onboardingDisclosureNeedWarningsBullet3.
  ///
  /// In en, this message translates to:
  /// **'Show a safety warning before you complete a potentially dangerous payment.'**
  String get onboardingDisclosureNeedWarningsBullet3;

  /// No description provided for @onboardingDisclosureDoesNotDoTitle.
  ///
  /// In en, this message translates to:
  /// **'What Guardian does not do'**
  String get onboardingDisclosureDoesNotDoTitle;

  /// No description provided for @onboardingDisclosureDoesNotStoreBullet1.
  ///
  /// In en, this message translates to:
  /// **'Guardian does not store your payment details.'**
  String get onboardingDisclosureDoesNotStoreBullet1;

  /// No description provided for @onboardingDisclosureDoesNotShareBullet2.
  ///
  /// In en, this message translates to:
  /// **'Guardian does not share your data with anyone.'**
  String get onboardingDisclosureDoesNotShareBullet2;

  /// No description provided for @onboardingDisclosureDoesNotBlockBullet3.
  ///
  /// In en, this message translates to:
  /// **'Guardian does not block payments. You always have the final say.'**
  String get onboardingDisclosureDoesNotBlockBullet3;

  /// No description provided for @onboardingDisclosureTurnOffTitle.
  ///
  /// In en, this message translates to:
  /// **'You can turn this off anytime'**
  String get onboardingDisclosureTurnOffTitle;

  /// No description provided for @onboardingDisclosureTurnOffBody.
  ///
  /// In en, this message translates to:
  /// **'Go to Settings > Accessibility > Guardian to disable protection.'**
  String get onboardingDisclosureTurnOffBody;

  /// No description provided for @onboardingDisclosureAgreeButton.
  ///
  /// In en, this message translates to:
  /// **'Open Android Accessibility settings'**
  String get onboardingDisclosureAgreeButton;

  /// No description provided for @onboardingDisclosureSkipLink.
  ///
  /// In en, this message translates to:
  /// **'You can skip this step'**
  String get onboardingDisclosureSkipLink;

  /// No description provided for @onboardingConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Data, Your Control'**
  String get onboardingConsentTitle;

  /// No description provided for @onboardingConsentWhatWeCollectTitle.
  ///
  /// In en, this message translates to:
  /// **'What we collect and why'**
  String get onboardingConsentWhatWeCollectTitle;

  /// No description provided for @onboardingConsentCollectMedicationBullet1.
  ///
  /// In en, this message translates to:
  /// **'Medication schedules and adherence - to send reminders and keep your family informed.'**
  String get onboardingConsentCollectMedicationBullet1;

  /// No description provided for @onboardingConsentCollectHealthBullet2.
  ///
  /// In en, this message translates to:
  /// **'Health reading images - to store for doctor visits. We do not extract or analyse these.'**
  String get onboardingConsentCollectHealthBullet2;

  /// No description provided for @onboardingConsentCollectPaymentBullet3.
  ///
  /// In en, this message translates to:
  /// **'Payment app activity - to detect and warn about potential scams.'**
  String get onboardingConsentCollectPaymentBullet3;

  /// No description provided for @onboardingConsentCollectUsageBullet4.
  ///
  /// In en, this message translates to:
  /// **'App usage patterns - to understand when payment protection is being used.'**
  String get onboardingConsentCollectUsageBullet4;

  /// No description provided for @onboardingConsentHowProtectedTitle.
  ///
  /// In en, this message translates to:
  /// **'How your data is protected'**
  String get onboardingConsentHowProtectedTitle;

  /// No description provided for @onboardingConsentProtectEncryptedBullet1.
  ///
  /// In en, this message translates to:
  /// **'Your data is encrypted in transit and at rest.'**
  String get onboardingConsentProtectEncryptedBullet1;

  /// No description provided for @onboardingConsentProtectNotSoldBullet2.
  ///
  /// In en, this message translates to:
  /// **'Your data is never sold or shared with advertisers.'**
  String get onboardingConsentProtectNotSoldBullet2;

  /// No description provided for @onboardingConsentProtectFamilyBullet3.
  ///
  /// In en, this message translates to:
  /// **'Your family guardian can only see what you have agreed to share.'**
  String get onboardingConsentProtectFamilyBullet3;

  /// No description provided for @onboardingConsentRightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your rights'**
  String get onboardingConsentRightsTitle;

  /// No description provided for @onboardingConsentRightsWithdrawBullet1.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw consent at any time in Settings.'**
  String get onboardingConsentRightsWithdrawBullet1;

  /// No description provided for @onboardingConsentRightsDeleteBullet2.
  ///
  /// In en, this message translates to:
  /// **'You can request deletion of all your data.'**
  String get onboardingConsentRightsDeleteBullet2;

  /// No description provided for @onboardingConsentRightsAccessBullet3.
  ///
  /// In en, this message translates to:
  /// **'You can ask us what data we hold about you.'**
  String get onboardingConsentRightsAccessBullet3;

  /// No description provided for @onboardingConsentCheckboxLabel.
  ///
  /// In en, this message translates to:
  /// **'I understand and consent to the data collection described above'**
  String get onboardingConsentCheckboxLabel;

  /// No description provided for @onboardingConsentPrivacyPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Read full privacy policy'**
  String get onboardingConsentPrivacyPolicyLabel;

  /// No description provided for @onboardingConsentContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingConsentContinueButton;

  /// No description provided for @onboardingRoleSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Whose phone is this?'**
  String get onboardingRoleSelectTitle;

  /// No description provided for @onboardingRoleSelectChildTitle.
  ///
  /// In en, this message translates to:
  /// **'I am the child / guardian'**
  String get onboardingRoleSelectChildTitle;

  /// No description provided for @onboardingRoleSelectChildSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up the account that helps and monitors the parent.'**
  String get onboardingRoleSelectChildSubtitle;

  /// No description provided for @onboardingRoleSelectParentTitle.
  ///
  /// In en, this message translates to:
  /// **'I am the parent / elder'**
  String get onboardingRoleSelectParentTitle;

  /// No description provided for @onboardingRoleSelectParentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up the account that receives help and protection.'**
  String get onboardingRoleSelectParentSubtitle;

  /// No description provided for @onboardingRoleSelectChildCta.
  ///
  /// In en, this message translates to:
  /// **'Choose child / guardian'**
  String get onboardingRoleSelectChildCta;

  /// No description provided for @onboardingRoleSelectParentCta.
  ///
  /// In en, this message translates to:
  /// **'Choose parent / elder'**
  String get onboardingRoleSelectParentCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
