import 'package:homeclient/core/constants/app_strings.dart';

String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return AppStrings.goodMorning;
  if (hour >= 12 && hour < 17) return AppStrings.goodAfternoon;
  if (hour >= 17 && hour < 21) return AppStrings.goodEvening;
  return AppStrings.goodNight;
}
