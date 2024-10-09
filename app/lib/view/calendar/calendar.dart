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
import '../../shared/types/calendar_event.dart';

class CalendarAnsicht extends StatefulWidget {
  const CalendarAnsicht({super.key});

  @override
  State<StatefulWidget> createState() => _CalendarAnsichtState();
}

class _CalendarAnsichtState extends State<CalendarAnsicht> {
  CalendarFetcher calendarFetcher = client.fetchers.calendarFetcher;

  late final ValueNotifier<List<CalendarEvent>> _selectedEvents;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<CalendarEvent> eventList = [];
  SearchController searchController = SearchController();

  @override
  void dispose() {
    _selectedEvents.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    searchController.addListener(() {
      if (!searchController.isOpen) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });

    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));

    calendarFetcher.fetchData();
  }

  List<CalendarEvent> fuzzySearchEventList(String query) {
    List<CalendarEvent> searchResults = [];
    for (var event in eventList) {
      String searchString = '${event.title} ${event.description} ${event.place??''} ${event.startTime.year}'.toLowerCase();
      if (searchString.contains(query.toLowerCase())) {
        searchResults.add(event);
      }
    }

    // Sort by distance to today
    searchResults.sort((a, b) {
      int distanceA = a.startTime.differenceInDays(DateTime.now());
      int distanceB = b.startTime.differenceInDays(DateTime.now());
      return distanceA.compareTo(distanceB);
    });

    // move elements of the past to the end
    searchResults.sort((a, b) {
      if (a.startTime.isBefore(DateTime.now()) && b.startTime.isAfter(DateTime.now())) {
        return 1;
      } else if (a.startTime.isAfter(DateTime.now()) && b.startTime.isBefore(DateTime.now())) {
        return -1;
      } else {
        return 0;
      }
    });

    return searchResults;
  }

  Future<Map<String, dynamic>?> fetchEvent(String id, {secondTry = false}) async {
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
    return null;
  }

  List<CalendarEvent> _getEventsForDay(DateTime day) {
    List<CalendarEvent> validEvents = [];

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

  Widget eventBottomSheet(CalendarEvent calendarData, Map<String, dynamic> singleEventData) {
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
            if (doesEntryExist(calendarData.place)) ...[
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
                    Text(calendarData.place!,
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
            if (doesEntryExist(calendarData.lerngruppe)) ...[
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
                      child: Text(calendarData.lerngruppe["Name"],
                          style: Theme.of(context).textTheme.labelLarge),
                    )
                  ],
                ),
              ),
            ],
            if (doesEntryExist(calendarData.description)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Linkify(
                  onOpen: (link) async {
                    if (!await launchUrl(Uri.parse(link.url))) {
                      logger.w("${link.url} konnte nicht geöffnet werden.");
                    }
                  },
                  text: calendarData.description.replaceAll("<br />", "\n"),
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

  void openEventBottomSheet(CalendarEvent calendarData, {bool unFocusAfter = true})  async {
    try {
      var singleEvent = await fetchEvent(calendarData.id);
      if (singleEvent == null) return;
      await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return eventBottomSheet(calendarData, singleEvent);
          });
      if (unFocusAfter) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    } on NoConnectionException {
      if (mounted) {
        return;
      }
    } on LanisException catch (ex) {
      if (mounted) {
        await showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (context) {
            return ErrorView(
              error: ex,
              name: "einem Kalenderereignis",
            );
          },
        );
        if (unFocusAfter) {
          FocusManager.instance.primaryFocus?.unfocus();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: SearchAnchor.bar(
            searchController: searchController,
            isFullScreen: false,
            barTrailing: [
              if (!_selectedDay!.isSameDay(DateTime.now())) IconButton(
                icon: const Icon(Icons.restore),
                onPressed: () {
                  setState(() {
                    searchController.text = "";
                    _selectedDay = DateTime.now();
                    _focusedDay = DateTime.now();
                  });
                },
              ),
            ],
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(FocusNode());
              //searchController.closeView(null);
            },
            suggestionsBuilder: (context, _searchController) {
                final results = fuzzySearchEventList(_searchController.text);

                return results.map((event) => ListTile(
                  title: Text(event.title),
                  subtitle: Text('${event.startTime.format("E d MMM y", "de_DE")} - ${event.endTime.format("E d MMM y", "de_DE")}'),
                  leading: event.endTime.isBefore(DateTime.now()) ? const Icon(Icons.done) : const Icon(Icons.event),
                  onTap: () {
                    setState(() {
                      _selectedDay = event.startTime;
                      _focusedDay = event.startTime;
                    });
                    _searchController.closeView(null);
                    FocusScope.of(context).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    openEventBottomSheet(event);
                  },
                ),
              ).toList();
            },
          ),
        ),
        Expanded(
            child: StreamBuilder<FetcherResponse<List<CalendarEvent>>>(
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
                  eventList = snapshot.data!.content ?? [];
                  _selectedEvents.value = _getEventsForDay(_selectedDay!);

                  return Column(
                    children: [
                      TableCalendar<CalendarEvent>(
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
                        pageJumpingEnabled: true,
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
                                borderRadius: BorderRadius.circular(24),
                            ),
                        ),
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                      ),
                      Expanded(
                        child: ValueListenableBuilder<List<CalendarEvent>>(
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
                                        title: Text(value[index].title),
                                        trailing: const Icon(Icons.arrow_right),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        onTap: () => openEventBottomSheet(value[index]),
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
              },
            )
        ),
      ],
    );
  }
}

List<DateTime> daysInRange(DateTime first, DateTime last) {
  final dayCount = last.difference(first).inDays + 1;
  return List.generate(
    dayCount,
    (index) => DateTime.utc(first.year, first.month, first.day + index),
  );
}
