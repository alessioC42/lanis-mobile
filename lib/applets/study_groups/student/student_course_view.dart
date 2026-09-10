import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:intl/intl.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentCourseView extends StatelessWidget {
  final List<StudentStudyGroup> studyGroup;

  const StudentCourseView({super.key, required this.studyGroup});

  BorderRadius getRadius(final int index, final int length) {
    if (length == 1) {
      return BorderRadius.circular(12.0);
    }

    if (index == 0) {
      return BorderRadius.vertical(top: Radius.circular(12.0));
    } else if (index == 1 && length == 2) {
      return BorderRadius.vertical(bottom: Radius.circular(12.0));
    } else {
      if (index == length - 1) {
        return BorderRadius.vertical(bottom: Radius.circular(12.0));
      }

      return BorderRadius.zero;
    }
  }

  List<StudentStudyGroupBySemester> groupBySemester() {
    Map<String, List<StudentStudyGroup>> grouped = {};
    for (var group in studyGroup) {
      grouped.putIfAbsent(group.semester, () => []).add(group);
    }
    return grouped.entries
        .map(
          (entry) => StudentStudyGroupBySemester(
            studyGroup: entry.value,
            semester: entry.key,
          ),
        )
        .toList();
  }

  Widget studyGroupTile(BuildContext context, StudentStudyGroup studyGroup) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  studyGroup.courseName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  studyGroup.courseSysId,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: studyGroup.teachers
                    .map(
                      (teacher) => Padding(
                        padding: const EdgeInsets.all(1.0),
                        child: TeacherChip(teacher: teacher),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (studyGroup.exams.isNotEmpty)
              ...studyGroup.exams.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: getRadius(i, studyGroup.exams.length),
                    color: i % 2 == 0
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                  child: Row(
                    spacing: 4.0,
                    children: [
                      Text(e.type),
                      Spacer(),
                      Text(DateFormat('EEE, dd.MM.yyyy').format(e.date)),
                      Icon(Icons.date_range, size: 14),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedStudyGroups = groupBySemester();

    return ListView.builder(
      itemCount: groupedStudyGroups.length,
      itemBuilder: (context, index) {
        final semesterStudyGroups = groupedStudyGroups[index];
        return Column(
          children: [
            Text(semesterStudyGroups.semester),
            Column(
              children: semesterStudyGroups.studyGroup.map((group) {
                return studyGroupTile(context, group);
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class TeacherChip extends StatefulWidget {
  final StudentStudyGroupTeacher teacher;

  const TeacherChip({super.key, required this.teacher});

  @override
  State<TeacherChip> createState() => _TeacherChipState();
}

class _TeacherChipState extends State<TeacherChip> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.teacher.email == null) return;

        final Uri emailLaunchUri = Uri(
          scheme: 'mailto',
          path: widget.teacher.email,
        );
        safeLaunchUrl(
          emailLaunchUri,
          context: context,
          mode: LaunchMode.externalApplication,
        );
      },
      behavior: HitTestBehavior.deferToChild,
      child: Chip(
        visualDensity: VisualDensity.compact,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 4.0,
          children: [
            Icon(Icons.person, size: 16),
            Text(
              "${widget.teacher.lastName}, ${widget.teacher.firstName} (${widget.teacher.krz})",
            ),
            if (widget.teacher.email != null)
              Icon(
                Icons.email,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class StudentStudyGroupBySemester {
  List<StudentStudyGroup> studyGroup;
  String semester;

  StudentStudyGroupBySemester({
    required this.studyGroup,
    required this.semester,
  });
}
