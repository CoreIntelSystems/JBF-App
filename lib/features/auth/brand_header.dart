import 'package:flutter/material.dart';

import '../../core/org_config.dart';

/// Logo placeholder and organisation name for the setup and login screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle});

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            OrgDefaults.logoAsset,
            width: 104,
            height: 104,
            semanticLabel: '${OrgDefaults.name} logo',
          ),
        ),
        const SizedBox(height: 16),
        Text(OrgDefaults.name, style: text.headlineSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: text.bodyMedium, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
