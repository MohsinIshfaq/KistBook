import 'package:intl/intl.dart';

class CurrencyHelper {
  static final NumberFormat pkr =
      NumberFormat.currency(locale: 'en_PK', symbol: 'Rs ', decimalDigits: 0);
}
