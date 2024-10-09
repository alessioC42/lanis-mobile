import 'package:intl/intl.dart';

class CalendarEvent {
  DateTime startTime;
  DateTime endTime;
  dynamic fremdUID;
  dynamic lerngruppe;
  bool secret;
  String id;
  String? schoolID;
  DateTime? lastModified;
  bool isNew;
  bool public;
  String? place;
  bool private;
  String? responsibleID;
  bool allDay;
  int? category;
  String description;
  String title;

  CalendarEvent({
    required this.startTime,
    required this.endTime,
    this.fremdUID,
    this.lerngruppe,
    required this.secret,
    required this.id,
    this.schoolID,
    this.lastModified,
    required this.isNew,
    required this.public,
    this.place,
    required this.private,
    this.responsibleID,
    required this.allDay,
    this.category,
    required this.description,
    required this.title,
  });

  ///Parses the response of the AJAX SPH events and returns a CalendarEvent object
  factory CalendarEvent.fromLanisJson(Map<String, dynamic> json) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    final data = CalendarEvent(
      startTime: formatter.parse(json['Anfang']),
      endTime: formatter.parse(json['Ende']),
      fremdUID: json['FremdUID'],
      lerngruppe: json['Lerngruppe']??null,
      secret: json['Geheim'] != 'nein',
      id: json['Id'],
      schoolID: json['Institution'],
      lastModified: json['LetzteAenderung'] != null ? formatter.parse(json['LetzteAenderung']) : null,
      isNew: json['Neu'] != 'nein',
      public: json['Oeffentlich'] != 'nein',
      place: json['Ort'],
      private: json['Privat'] != 'nein',
      responsibleID: json['Verantwortlich'],
      allDay: json['allDay'] ?? false,
      category: int.tryParse('${json['category']}'),
      description: json['description'] ?? '',
      title: json['title'] ?? '',
    );
    return data;
  }
}
