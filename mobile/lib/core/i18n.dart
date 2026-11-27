import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_store.dart';

const langKey = 'monova.lang';

/// Languages the app can be shown in. Names are written in each language so people can find their own.
enum AppLang {
  en('English', 'en'),
  hi('हिन्दी', 'hi'),
  te('తెలుగు', 'te');

  const AppLang(this.label, this.code);

  final String label;
  final String code;

  static AppLang fromCode(String? code) => AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.en);
}

/// The language in use. Set by [LanguageController]; read by [tr].
AppLang currentLang = AppLang.en;

const _strings = <String, Map<AppLang, String>>{
  'nav_home': {AppLang.en: 'Home', AppLang.hi: 'होम', AppLang.te: 'హోమ్'},
  'nav_activity': {AppLang.en: 'Activity', AppLang.hi: 'गतिविधि', AppLang.te: 'కార్యకలాపం'},
  'nav_insights': {AppLang.en: 'Insights', AppLang.hi: 'इनसाइट्स', AppLang.te: 'ఇన్‌సైట్స్'},
  'nav_groups': {AppLang.en: 'Groups', AppLang.hi: 'समूह', AppLang.te: 'గ్రూపులు'},
  'nav_add': {AppLang.en: 'Add', AppLang.hi: 'जोड़ें', AppLang.te: 'జోడించు'},
  'nav_accounts': {AppLang.en: 'Accounts', AppLang.hi: 'खाते', AppLang.te: 'ఖాతాలు'},
  'nav_credit_cards': {AppLang.en: 'Credit cards', AppLang.hi: 'क्रेडिट कार्ड', AppLang.te: 'క్రెడిట్ కార్డులు'},
  'nav_lending': {AppLang.en: 'Lending', AppLang.hi: 'उधार देना', AppLang.te: 'అప్పు ఇవ్వడం'},
  'nav_loans': {AppLang.en: 'Loans and EMI', AppLang.hi: 'लोन और ईएमआई', AppLang.te: 'లోన్లు మరియు EMI'},
  'nav_budgets': {AppLang.en: 'Budgets and savings', AppLang.hi: 'बजट और बचत', AppLang.te: 'బడ్జెట్ మరియు పొదుపు'},
  'nav_recurring': {AppLang.en: 'Recurring', AppLang.hi: 'आवर्ती', AppLang.te: 'పునరావృత'},
  'nav_all_services': {AppLang.en: 'All services', AppLang.hi: 'सभी सेवाएँ', AppLang.te: 'అన్ని సేవలు'},
  'nav_calculators': {AppLang.en: 'Calculators', AppLang.hi: 'कैलकुलेटर', AppLang.te: 'కాలిక్యులేటర్లు'},
  'nav_vault': {AppLang.en: 'Passwords and notes', AppLang.hi: 'पासवर्ड और नोट्स', AppLang.te: 'పాస్‌వర్డ్‌లు మరియు నోట్స్'},
  'nav_credit_book': {AppLang.en: 'Credit book', AppLang.hi: 'उधार खाता', AppLang.te: 'క్రెడిట్ బుక్'},
  'nav_saved_cards': {AppLang.en: 'Saved cards', AppLang.hi: 'सेव्ड कार्ड', AppLang.te: 'సేవ్ చేసిన కార్డులు'},
  'nav_backup': {AppLang.en: 'Backup and restore', AppLang.hi: 'बैकअप और रिस्टोर', AppLang.te: 'బ్యాకప్ మరియు రీస్టోర్'},
  'nav_settings': {AppLang.en: 'Settings', AppLang.hi: 'सेटिंग्स', AppLang.te: 'సెట్టింగ్‌లు'},
  'section_overview': {AppLang.en: 'Overview', AppLang.hi: 'सारांश', AppLang.te: 'అవలోకనం'},
  'section_money': {AppLang.en: 'Money', AppLang.hi: 'पैसा', AppLang.te: 'డబ్బు'},
  'section_tools': {AppLang.en: 'Tools', AppLang.hi: 'उपकरण', AppLang.te: 'సాధనాలు'},
  'add_entry': {AppLang.en: 'Add entry', AppLang.hi: 'एंट्री जोड़ें', AppLang.te: 'ఎంట్రీ జోడించు'},
  'sign_in': {AppLang.en: 'Sign in', AppLang.hi: 'साइन इन', AppLang.te: 'సైన్ ఇన్'},
  'settings_language': {AppLang.en: 'Language', AppLang.hi: 'भाषा', AppLang.te: 'భాష'},
  'settings_language_note': {
    AppLang.en: 'Menus and main labels change at once. Some pages stay in English for now.',
    AppLang.hi: 'मेनू और मुख्य लेबल तुरंत बदल जाते हैं। कुछ पेज अभी अंग्रेज़ी में हैं।',
    AppLang.te: 'మెనూలు మరియు ప్రధాన లేబుళ్ళు వెంటనే మారతాయి. కొన్ని పేజీలు ఇంకా ఇంగ్లీష్‌లో ఉన్నాయి.',
  },
  'nav_money': {AppLang.en: 'Money', AppLang.te: 'డబ్బు'},
  'nav_explore': {AppLang.en: 'Explore', AppLang.te: 'అన్వేషించు'},
  'nav_profile': {AppLang.en: 'Profile', AppLang.te: 'ప్రొఫైల్'},
  'money_this_month': {AppLang.en: 'This month', AppLang.te: 'ఈ నెల'},
  'money_in': {AppLang.en: 'Money in', AppLang.te: 'వచ్చిన డబ్బు'},
  'money_out': {AppLang.en: 'Money out', AppLang.te: 'ఖర్చైన డబ్బు'},
  'money_left': {AppLang.en: 'Left over', AppLang.te: 'మిగిలింది'},
  'money_record_check': {AppLang.en: 'Record and check', AppLang.te: 'నమోదు చేసి చూడండి'},
  'money_income_spending': {AppLang.en: 'Income and spending', AppLang.te: 'ఆదాయం, ఖర్చు'},
  'money_purchases': {AppLang.en: 'Purchases and warranties', AppLang.te: 'కొనుగోళ్లు, వారంటీలు'},
  'money_credit_book': {AppLang.en: 'Credit book', AppLang.te: 'క్రెడిట్ పుస్తకం'},
  'money_split': {AppLang.en: 'Split bills and groups', AppLang.te: 'బిల్లులు, గ్రూపులు పంచుకోండి'},
  'money_property': {AppLang.en: 'Property rent and expenses', AppLang.te: 'అద్దె, ఆస్తి ఖర్చులు'},
  'money_cards': {AppLang.en: 'Saved cards', AppLang.te: 'సేవ్ చేసిన కార్డులు'},
  'money_calculators': {AppLang.en: 'Calculators', AppLang.te: 'కాలిక్యులేటర్లు'},
  'money_loans': {AppLang.en: 'Loans and borrowing', AppLang.te: 'అప్పులు, తీసుకున్న డబ్బు'},
  'money_plans': {AppLang.en: 'Budgets, goals and recurring', AppLang.te: 'బడ్జెట్, లక్ష్యాలు, నెలవారీ ఖర్చులు'},
  'money_documents': {AppLang.en: 'Documents and receipts', AppLang.te: 'పత్రాలు, రసీదులు'},
  'money_report': {AppLang.en: 'Monthly report', AppLang.te: 'నెలవారీ నివేదిక'},
  'add_options_title': {AppLang.en: 'What would you like to save?', AppLang.te: 'మీరు ఏమి సేవ్ చేయాలనుకుంటున్నారు?'},
  'attention_title': {AppLang.en: 'Needs attention', AppLang.te: 'శ్రద్ధ అవసరం'},
  'attention_none': {AppLang.en: 'Nothing needs your attention today.', AppLang.te: 'ఈ రోజు శ్రద్ధ అవసరమైనది ఏదీ లేదు.'},
  'reminders_title': {AppLang.en: 'Reminders', AppLang.te: 'రిమైండర్లు'},
  'add_reminder': {AppLang.en: 'Add reminder', AppLang.te: 'రిమైండర్ జోడించు'},
};

/// Looks up a label in the current language. Falls back to English, then to the key itself.
String tr(String key) {
  final row = _strings[key];
  if (row == null) return key;
  return row[currentLang] ?? row[AppLang.en] ?? key;
}

class LanguageController extends Notifier<AppLang> {
  @override
  AppLang build() {
    _load();
    return AppLang.en;
  }

  Future<void> _load() async {
    final store = await LocalStore.open();
    final raw = store.readList(langKey);
    final code = raw.isEmpty ? null : '${raw.first['code']}';
    _apply(AppLang.fromCode(code));
  }

  Future<void> set(AppLang lang) async {
    _apply(lang);
    final store = await LocalStore.open();
    await store.writeList(langKey, [
      {'code': lang.code},
    ]);
  }

  void _apply(AppLang lang) {
    currentLang = lang;
    state = lang;
  }
}

final languageProvider = NotifierProvider<LanguageController, AppLang>(LanguageController.new);

/// Locale for Material widgets (dates, dialogs), so built-in text follows the language too.
Locale localeFor(AppLang lang) => Locale(lang.code);
