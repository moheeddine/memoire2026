import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── REQUIRED LABEL ───────────────────────────────────────────────────────────
//
// Drop-in label for any form field. When isRequired is true (default), appends
// a ✱ badge in AppColors.error. Tapping the badge shows a "Champ obligatoire"
// tooltip. The bottom padding (8 px) matches every _sectionLabel / _label
// helper in the codebase so it is a true plug-in replacement.
//
// Usage:
//   const RequiredLabel('Email')                       // required (default)
//   const RequiredLabel('Message', isRequired: false)  // optional — plain label

class RequiredLabel extends StatelessWidget {
  final String text;
  final bool   isRequired;

  const RequiredLabel(
    this.text, {
    super.key,
    this.isRequired = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            text,
            style: const TextStyle(
              color:      AppColors.textDark,
              fontSize:   13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 5),
            Tooltip(
              message:     'Champ obligatoire',
              preferBelow: false,
              triggerMode: TooltipTriggerMode.tap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color:        AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '✱',
                  style: TextStyle(
                    color:      AppColors.error,
                    fontSize:   10,
                    fontWeight: FontWeight.w900,
                    height:     1.2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
