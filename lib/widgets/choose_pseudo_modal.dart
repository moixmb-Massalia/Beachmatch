import 'package:flutter/material.dart';

/// Pop-up de pseudo désactivée à la demande utilisateur.
class ChoosePseudoModal extends StatelessWidget {
  const ChoosePseudoModal({super.key});

  static Future<void> showIfNeeded(BuildContext context) async {
    // Désactivé définitivement
    return;
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
