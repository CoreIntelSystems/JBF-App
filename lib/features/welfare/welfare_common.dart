import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/welfare_repository.dart';
import '../../domain/permissions.dart';

extension WelfareUser on AppUser {
  WelfareActor welfareActor(String deviceId) => WelfareActor(
    actor(deviceId),
    name: displayName,
    roleName: roleName,
    mayApproveOwn: roleKey == 'founder' || roleKey == 'super_admin',
  );

  bool get canViewWelfare =>
      can(Perm.welfarePrepare) ||
      can(Perm.welfareApprove) ||
      can(Perm.welfareSetBenefits) ||
      can(Perm.welfarePay) ||
      can(Perm.financeView);
}

class WelfareStatusChip extends StatelessWidget {
  const WelfareStatusChip({super.key, required this.status});
  final WelfareStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      WelfareStatus.pending => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      WelfareStatus.approved => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      WelfareStatus.rejected => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      WelfareStatus.paid => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status == WelfareStatus.approved ? 'Approved' : status.label,
        style: TextStyle(color: fg, fontSize: 12),
      ),
    );
  }
}
