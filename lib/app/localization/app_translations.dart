import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'app_en_us.dart';
import 'app_ur_pk.dart';

class AppTranslations extends Translations {
  static const english = 'English';
  static const urdu = 'اردو';

  static const locales = <Locale>[
    Locale('en', 'US'),
    Locale('ur', 'PK'),
  ];

  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': appEnUs,
        'ur_PK': appUrPk,
      };
}
