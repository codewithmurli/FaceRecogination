import 'package:flutter/material.dart';

import '../../constants/theme.dart';

class CustomSnackBar {
  static late BuildContext context;

  static errorSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          // Use colorScheme.error instead of errorColor
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

  static successSnackBar(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          // Assuming 'accentColor' is defined elsewhere, if not, you might want to use Theme.of(context).colorScheme.secondary or a custom color.
          backgroundColor: accentColor,
        ),
      );
}