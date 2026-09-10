import 'package:flutter/material.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/applets/lessons/routes.dart';
import 'package:lanis/applets/lessons/student/lessons_student_view.dart';
import 'package:lanis/applets/lessons/teacher/lessons_teacher_view.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/utils/deep_link.dart';

final lessonsDefinition = AppletDefinition(
  appletPhpUrl: 'meinunterricht.php',
  pathSegment: 'lessons',
  deepLinkScope: DeepLinkScope.accountTyped,
  buildRoutes: buildLessonsRoutes,
  addDivider: false,
  appletType: AppletType.nested,
  icon: const Icon(Icons.school),
  selectedIcon: const Icon(Icons.school_outlined),
  label: (context) => AppLocalizations.of(context).lessons,
  supportedAccountTypes: [AccountType.student],
  allowOffline: false,
  settingsDefaults: {'showHomework': false},
  refreshInterval: const Duration(minutes: 15),
  bodyBuilder: (context, accountType, openDrawerCb) {
    if (accountType == AccountType.student) {
      return LessonsStudentView(openDrawerCb: openDrawerCb);
    } else if (accountType == AccountType.teacher) {
      return LessonsTeacherView(openDrawerCb: openDrawerCb);
    }
    throw UnsupportedError('Lessons are not available for this account type');
  },
);
