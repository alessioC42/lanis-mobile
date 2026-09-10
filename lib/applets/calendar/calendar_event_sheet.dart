import 'package:dart_date/dart_date.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:liblanis/liblanis.dart';
import 'package:linkify/linkify.dart';

import '../../utils/safe_launch.dart';

bool doesCalendarEntryExist(dynamic entry) => entry != null && entry != "";

/// Detail sheet content for a single calendar event.
class CalendarEventBottomSheet extends StatelessWidget {
  final CalendarEvent calendarData;
  final Map<String, dynamic> singleEventData;

  const CalendarEventBottomSheet({
    super.key,
    required this.calendarData,
    required this.singleEventData,
  });

  @override
  Widget build(BuildContext context) {
    const double iconSize = 24;

    // German-formatted readable date string
    String date = "";

    String startTime = calendarData.startTime.format("E d MMM y", "de_DE");
    String endTime = calendarData.endTime.format("E d MMM y", "de_DE");

    if (calendarData.allDay) {
      if (startTime == endTime) {
        date += startTime;
      } else {
        date += "$startTime bis $endTime";
      }
    } else {
      if (startTime == endTime) {
        date +=
            "${calendarData.startTime.format("E d MMM y H:mm", "de_DE")} bis ${calendarData.endTime.format("H:mm", "de_DE")}";
      } else {
        date +=
            "${calendarData.startTime.format("E d MMM y H:mm", "de_DE")} bis ${calendarData.endTime.format("E MMM d y H:mm", "de_DE")}";
      }
    }

    // For which group (Public, Students & Parents, Teachers) it's targeted for.
    String targetGroup = "";

    if (doesCalendarEntryExist(singleEventData["properties"]) &&
        doesCalendarEntryExist(singleEventData["properties"]["zielgruppen"])) {
      Map<String, dynamic> data = singleEventData["properties"]["zielgruppen"];

      data.forEach((key, value) {
        if (key == "-sus") {
          targetGroup += value.replaceAll("amp;", "").toString();
          return;
        }
        targetGroup += "$value, ";
      });
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: ListView(
        shrinkWrap: true,
        children: [
          // Title
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              calendarData.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Responsible (Teacher, Admin, ...)
          if (doesCalendarEntryExist(singleEventData["properties"]) &&
              doesCalendarEntryExist(
                singleEventData["properties"]["verantwortlich"],
              )) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.person, size: iconSize),
                  ),
                  Text(
                    singleEventData["properties"]["verantwortlich"],
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
          // Time
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Icon(Icons.access_time_filled, size: iconSize),
                ),
                Flexible(
                  child: Text(
                    date,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
          // Place
          if (doesCalendarEntryExist(calendarData.place)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.place, size: iconSize),
                  ),
                  Text(
                    calendarData.place!,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ],
          // Target group
          if (doesCalendarEntryExist(singleEventData["properties"]) &&
              doesCalendarEntryExist(
                singleEventData["properties"]["zielgruppen"],
              )) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.group, size: iconSize),
                  ),
                  Flexible(
                    child: Text(
                      targetGroup,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (doesCalendarEntryExist(calendarData.lerngruppe)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.school, size: iconSize),
                  ),
                  Flexible(
                    child: Text(
                      calendarData.lerngruppe["Name"],
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (doesCalendarEntryExist(calendarData.description)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text.rich(
                TextSpan(
                  children:
                      linkify(
                        calendarData.description.replaceAll("<br />", "\n"),
                        options: const LinkifyOptions(humanize: true),
                        linkifiers: const [EmailLinkifier(), UrlLinkifier()],
                      ).map((element) {
                        if (element is LinkableElement) {
                          return TextSpan(
                            text: element.text,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                safeLaunchUrl(
                                  Uri.parse(element.url),
                                  context: context,
                                );
                              },
                          );
                        }
                        return TextSpan(text: element.text);
                      }).toList(),
                ),
              ),
            ),
          ],
          SizedBox(height: 50.0),
        ],
      ),
    );
  }
}
