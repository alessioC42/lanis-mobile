import 'package:flutter/material.dart';
import 'package:flutter_tagging_plus/flutter_tagging_plus.dart';

class ReceiverEntry extends Taggable {
  final String id;
  final String name;
  final bool isTeacher;

  const ReceiverEntry(this.id, this.name, this.isTeacher);

  @override
  List<Object> get props => [name];

  ReceiverEntry.fromJson(Map<String, dynamic> json)
    : id = json["id"] as String,
      name = json["text"] as String,
      isTeacher = json["type"] == "lul"; // TODO: Use PersonType in future when I have more info
}

class ChatCreationData {
  final ChatType? type;
  final String subject;
  final List<String> receivers;

  ChatCreationData(
      {required this.type, required this.subject, required this.receivers});
}

class CreationResponse {
  final bool success;
  String? id;

  CreationResponse({required this.success, this.id});
}

enum ChatType {
  noAnswerAllowed(Icons.speaker_notes_off),
  privateAnswerOnly(Icons.mic),
  groupOnly(Icons.forum),
  openChat(Icons.groups);

  final IconData icon;

  const ChatType(this.icon);
}

enum PersonType {
  teacher(Icons.school),
  parent(Icons.supervisor_account),
  group(Icons.group),
  other(Icons.person); // Unknown or student

  final IconData icon;

  const PersonType(this.icon);

  static PersonType fromJson(String type) {
    if (type == "Betreuer") {
      return PersonType.teacher;
    } else if (type == "Eltern") {
      return PersonType.parent;
    }

    return PersonType.other;
  }
}

class Conversation {
  final bool groupChat;
  final bool onlyPrivateAnswers;

  final bool noReply;

  final int countStudents;
  final int countTeachers;
  final int countParents;

  final List<KnownParticipant> knownParticipants;

  final UnparsedMessage parent;
  final List<UnparsedMessage> replies;

  const Conversation(
      {required this.groupChat,
      required this.onlyPrivateAnswers,
      required this.noReply,
      required this.parent,
      required this.countParents,
      required this.countStudents,
      required this.countTeachers,
      required this.knownParticipants,
      this.replies = const []});
}

class UnparsedMessage {
  final String date;
  final String author;
  final bool own;
  final String content;

  const UnparsedMessage(
      {required this.date,
      required this.author,
      required this.own,
      required this.content});
}

class KnownParticipant {
  final String name;
  final PersonType type;

  const KnownParticipant({
    required this.name,
    required this.type
  });

  // lazy way to make Set<> work.
  @override
  int get hashCode => name.hashCode;

  @override
  bool operator ==(Object other) {
    return other is KnownParticipant && other.hashCode == hashCode;
  }
}
