import 'package:dart_date/dart_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:sph_plan/client/fetcher.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client/client.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../client/logger.dart';
import '../../shared/widgets/error_view.dart';

class CalendarAnsicht extends StatefulWidget {
  const CalendarAnsicht({super.key});

  @override
  State<StatefulWidget> createState() => _CalendarAnsichtState();
}

class _CalendarAnsichtState extends State<CalendarAnsicht> {
  CalendarFetcher calendarFetcher = client.fetchers.calendarFetcher;

  late final ValueNotifier<List<Event>> _selectedEvents;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Event> eventList = [];

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    calendarFetcher.fetchData();
  }

  Future<dynamic> fetchEvent(String id, {secondTry = false}) async {
    try {
      if (secondTry) {
        await client.login();
      }

      return await client.calendar.getEvent(id);
    } catch (e) {
      if (!secondTry) {
        fetchEvent(id, secondTry: true);
      }
    }
  }

  List<Event> _getEventsForDay(DateTime day) {
    List<Event> validEvents = [];

    for (var event in eventList) {
      // Compare only the date part of startTime and endTime
      bool isStartTimeOnDay = event.startTime.year == day.year &&
          event.startTime.month == day.month &&
          event.startTime.day == day.day;

      bool isEndTimeOnDay = event.endTime.year == day.year &&
          event.endTime.month == day.month &&
          event.endTime.day == day.day;

      if ((isStartTimeOnDay || event.startTime.isBefore(day)) &&
          (isEndTimeOnDay || event.endTime.isAfter(day))) {
        validEvents.add(event);
      }
    }

    return validEvents;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });

      _selectedEvents.value = _getEventsForDay(selectedDay);
    }
  }

  bool doesEntryExist(dynamic entry) => entry != null && entry != "";

  Widget getEvent(Event calendarData, Map<String, dynamic> singleEventData) {
    const double iconSize = 24;

    // German-formatted readable date string
    String date = "";

    String startTime = calendarData.startTime.format("E d MMM y", "de_DE");
    String endTime = calendarData.endTime.format("E d MMM y", "de_DE");

    if (calendarData.data["allDay"] == true) {
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

    if (doesEntryExist(singleEventData["properties"]) &&
        doesEntryExist(singleEventData["properties"]["zielgruppen"])) {
      Map<String, dynamic> data = singleEventData["properties"]["zielgruppen"];

      data.forEach((key, value) {
        if (key == "-sus") {
          targetGroup += value.replaceAll("amp;", "").toString();
          return;
        }
        targetGroup += "$value, ";
      });
    }

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            if (doesEntryExist(singleEventData["properties"]) &&
                doesEntryExist(
                    singleEventData["properties"]["verantwortlich"])) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.person,
                        size: iconSize,
                      ),
                    ),
                    Text(
                      singleEventData["properties"]["verantwortlich"],
                      style: Theme.of(context).textTheme.labelLarge,
                    )
                  ],
                ),
              )
            ],
            // Time
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.access_time_filled,
                      size: iconSize,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      date,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  )
                ],
              ),
            ),
            // Place
            if (doesEntryExist(calendarData.data["Ort"])) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.place,
                        size: iconSize,
                      ),
                    ),
                    Text(calendarData.data["Ort"],
                        style: Theme.of(context).textTheme.labelLarge)
                  ],
                ),
              ),
            ],
            // Target group
            if (doesEntryExist(singleEventData["properties"]) &&
                doesEntryExist(
                    singleEventData["properties"]["zielgruppen"])) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.group,
                        size: iconSize,
                      ),
                    ),
                    Flexible(
                      child: Text(targetGroup,
                          style: Theme.of(context).textTheme.labelLarge),
                    )
                  ],
                ),
              ),
            ],
            if (doesEntryExist(calendarData.data["Lerngruppe"])) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        Icons.school,
                        size: iconSize,
                      ),
                    ),
                    Flexible(
                      child: Text(calendarData.data["Lerngruppe"]["Name"],
                          style: Theme.of(context).textTheme.labelLarge),
                    )
                  ],
                ),
              ),
            ],
            if (doesEntryExist(calendarData.data["description"])) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Linkify(
                  onOpen: (link) async {
                    if (!await launchUrl(Uri.parse(link.url))) {
                      logger.w("${link.url} konnte nicht geöffnet werden.");
                    }
                  },
                  text: calendarData.data["description"]
                      .replaceAll("<br />", "\n"),
                  style: Theme.of(context).textTheme.bodyLarge,
                  linkStyle: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FetcherResponse>(
        stream: calendarFetcher.stream,
        builder: (context, snapshot) {
          if (snapshot.data?.status == FetcherStatus.error) {
            return ErrorView(
                error: snapshot.data!.error!,
                name: "Kalender",
                retry: retryFetcher(calendarFetcher));
          } else if (snapshot.data?.status == FetcherStatus.fetching ||
              snapshot.data == null) {
            return const Center(child: CircularProgressIndicator());
          } else {
            List<Event> updatedEventList = [];

            snapshot.data?.content.forEach((event) {
              updatedEventList.add(Event(
                  event["title"],
                  event,
                  parseDateString(event["Anfang"]),
                  parseDateString(event["Ende"])));
            });

            eventList = updatedEventList;
            _selectedEvents.value = _getEventsForDay(_selectedDay!);

            return Column(
              children: [
                TableCalendar<Event>(
                  locale: AppLocalizations.of(context)!.locale,
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.utc(2030),
                  availableCalendarFormats: {
                    CalendarFormat.month:
                        AppLocalizations.of(context)!.calendarFormatMonth,
                    CalendarFormat.twoWeeks:
                        AppLocalizations.of(context)!.calendarFormatTwoWeeks,
                    CalendarFormat.week:
                        AppLocalizations.of(context)!.calendarFormatWeek,
                  },
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  eventLoader: _getEventsForDay,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultDecoration:
                          const BoxDecoration(shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle),
                      selectedTextStyle: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).colorScheme.onPrimary),
                      todayDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontSize: 16,
                      ),
                      markerDecoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.inversePrimary)),
                  onDaySelected: _onDaySelected,
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    }
                  },
                  headerStyle: HeaderStyle(
                      formatButtonTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary),
                      formatButtonDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(24))),
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<List<Event>>(
                    valueListenable: _selectedEvents,
                    builder: (context, value, _) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: ListView.builder(
                          itemCount: value.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                  left: 8, right: 8, bottom: 4),
                              child: Card(
                                child: ListTile(
                                  title: Text('${value[index]}'),
                                  trailing: const Icon(Icons.arrow_right),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  onTap: () async {
                                    try {
                                      var singleEvent = await fetchEvent(
                                          value[index].data["Id"]);
                                      showModalBottomSheet(
                                          context: context,
                                          showDragHandle: true,
                                          builder: (context) {
                                            return getEvent(
                                                value[index], singleEvent);
                                          });
                                    } on NoConnectionException {
                                      if (mounted) {
                                        return;
                                      }
                                    } on LanisException catch (ex) {
                                      if (mounted) {
                                        showModalBottomSheet(
                                            context: context,
                                            showDragHandle: true,
                                            builder: (context) {
                                              return ErrorView(
                                                error: ex,
                                                name: "einem Kalenderereignis",
                                              );
                                            });
                                      }
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        });
  }
}

class Event {
  final String title;
  final Map<String, dynamic> data;
  final DateTime startTime;
  final DateTime endTime;

  const Event(this.title, this.data, this.startTime, this.endTime);

  @override
  String toString() => title;
}

List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}

DateTime parseDateString(String dateString) {
  // Parse the date string
  List<String> dateTimeParts = dateString.split(' ');
  List<String> dateParts = dateTimeParts[0].split('-');
  List<String> timeParts = dateTimeParts[1].split(':');

  // Extract year, month, day, hour, minute, and second
  int year = int.parse(dateParts[0]);
  int month = int.parse(dateParts[1]);
  int day = int.parse(dateParts[2]);
  int hour = int.parse(timeParts[0]);
  int minute = int.parse(timeParts[1]);
  int second = int.parse(timeParts[2]);

  // Create a DateTime object
  DateTime dateTime = DateTime(year, month, day, hour, minute, second);

  return dateTime;
}
