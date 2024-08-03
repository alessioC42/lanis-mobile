// Shared classes and functions between the conversation screens.
import 'package:flutter/material.dart';
import 'package:color_hash/color_hash.dart';
import 'package:flutter_chat_bubble/bubble_type.dart';
import 'package:flutter_chat_bubble/clippers/chat_bubble_clipper_1.dart';
import 'package:sph_plan/shared/types/conversations.dart';
import 'package:sph_plan/shared/widgets/format_text.dart';

class ConversationSettings {
  final String id; // uniqueId
  final bool groupChat;
  final bool onlyPrivateAnswers;
  final bool noReply;
  final bool own;
  final String? author;

  const ConversationSettings(
      {required this.id,
      required this.groupChat,
      required this.onlyPrivateAnswers,
      required this.noReply,
      required this.own,
      this.author});
}

class ParticipationStatistics {
  final int countStudents;
  final int countTeachers;
  final int countParents;
  final List<KnownParticipant> knownParticipants;

  const ParticipationStatistics(
      {required this.countParents,
      required this.countStudents,
      required this.countTeachers,
      required this.knownParticipants});
}

class NewConversationSettings {
  final Message firstMessage;
  final ConversationSettings settings;

  NewConversationSettings({required this.firstMessage, required this.settings});
}

class Message {
  final String text;
  final bool own;
  final String? author;
  final DateTime date;
  final MessageState state;
  MessageStatus status;

  Message(
      {required this.text,
      required this.own,
      required this.date,
      required this.author,
      required this.state,
      required this.status});
}

enum MessageStatus {
  sending,
  sent,
  error;
}

enum MessageState {
  first,
  series;
}

class DateHeader {
  final DateTime date;

  const DateHeader({required this.date});
}

class BubbleStructure {
  static const double nipWidth = 12.0;
  static const double horizontalPadding = 14.0;
  static const double compensatedPadding = horizontalPadding + nipWidth;
  static const double horizontalMargin = 8.0;
  static BorderRadius radius = BorderRadius.circular(20.0);

  static CrossAxisAlignment getAlignment(final bool own) {
    return own ? CrossAxisAlignment.end : CrossAxisAlignment.start;
  }

  static CustomClipper<Path> getFirstStateClipper(final bool own) {
    return ChatBubbleClipper1(
        type: own ? BubbleType.sendBubble : BubbleType.receiverBubble,
        nipWidth: nipWidth,
        nipHeight: 14,
        radius: 20,
        nipRadius: 4);
  }

  static EdgeInsets getPadding(final bool nipCompensation, final bool own) {
    final double margin =
        nipCompensation ? compensatedPadding : horizontalPadding;

    return EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: own ? horizontalPadding : margin,
        right: own ? margin : horizontalPadding);
  }

  static EdgeInsets getMargin(final MessageState state) {
    final double combinedMargin = state == MessageState.first
        ? horizontalMargin
        : horizontalMargin + nipWidth;

    return EdgeInsets.only(
        left: combinedMargin,
        right: combinedMargin,
        top: state == MessageState.first ? 8.0 : 2.0);
  }
}

abstract class BubbleStyles {
  static late BubbleStyle own;
  static late BubbleStyle other;

  static void init(final ThemeData theme) {
    final TextStyle baseTextStyle = theme.textTheme.bodyMedium!;
    final TextStyle dateTextStyle =
        theme.textTheme.bodySmall!.copyWith(color: theme.colorScheme.onSurface);

    if (theme.brightness == Brightness.dark) {
      other = BubbleStyle(
          mainColor: theme.colorScheme.inversePrimary,
          pressedColor: theme.colorScheme.inversePrimary.withOpacity(0.65),
          mainTextStyle: baseTextStyle.copyWith(
              color: theme.colorScheme.onSurface,
              decorationColor: theme.colorScheme.onPrimary),
          dateTextStyle: dateTextStyle,
          textFormatStyle: FormatStyle(
              textStyle: baseTextStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                  decorationColor: theme.colorScheme.onPrimary),
              timeColor: theme.colorScheme.primary,
              linkBackground: theme.colorScheme.primaryFixedDim,
              linkForeground: theme.colorScheme.onPrimaryFixedVariant,
              codeBackground: theme.colorScheme.primaryContainer,
              codeForeground: theme.colorScheme.onPrimaryContainer));

      own = BubbleStyle(
          mainColor: theme.colorScheme.surfaceContainerHighest,
          pressedColor: theme.colorScheme.surfaceContainerHigh,
          mainTextStyle: baseTextStyle.copyWith(
              color: theme.colorScheme.onSurface,
              decorationColor: theme.colorScheme.onSecondary),
          dateTextStyle: dateTextStyle,
          textFormatStyle: FormatStyle(
              textStyle: baseTextStyle.copyWith(
                  color: theme.colorScheme.onSurface,
                  decorationColor: theme.colorScheme.onSecondary),
              timeColor: theme.colorScheme.secondaryFixed,
              linkBackground: theme.colorScheme.secondaryFixedDim,
              linkForeground: theme.colorScheme.onSecondaryFixedVariant,
              codeBackground: theme.colorScheme.secondaryContainer,
              codeForeground: theme.colorScheme.onSecondaryContainer));
    } else {
      other = BubbleStyle(
          mainColor: theme.colorScheme.primaryFixed,
          pressedColor: theme.colorScheme.primaryFixed.withOpacity(0.65),
          mainTextStyle: baseTextStyle.copyWith(
              color: theme.colorScheme.onPrimaryFixedVariant,
              decorationColor: theme.colorScheme.onPrimaryFixedVariant),
          dateTextStyle: dateTextStyle,
          textFormatStyle: FormatStyle(
              textStyle: baseTextStyle.copyWith(
                  color: theme.colorScheme.onPrimaryFixedVariant,
                  decorationColor: theme.colorScheme.onPrimaryFixedVariant),
              timeColor: theme.colorScheme.primary,
              linkBackground: theme.colorScheme.primaryFixedDim,
              linkForeground: theme.colorScheme.onPrimaryFixedVariant,
              codeBackground: theme.colorScheme.primary.withOpacity(0.3),
              codeForeground: theme.colorScheme.onPrimaryFixedVariant));

      own = BubbleStyle(
          mainColor: theme.colorScheme.surfaceContainer,
          pressedColor: theme.colorScheme.surfaceContainerLow,
          mainTextStyle: baseTextStyle.copyWith(
              color: theme.colorScheme.onSecondaryFixed,
              decorationColor: theme.colorScheme.onSecondaryFixed),
          dateTextStyle: dateTextStyle,
          textFormatStyle: FormatStyle(
              textStyle: baseTextStyle.copyWith(
                  color: theme.colorScheme.onSecondaryFixed,
                  decorationColor: theme.colorScheme.onSecondaryFixed),
              timeColor: theme.colorScheme.primary,
              linkBackground: theme.colorScheme.secondaryFixedDim,
              linkForeground: theme.colorScheme.onSecondaryFixedVariant,
              codeBackground: theme.colorScheme.primaryContainer,
              codeForeground: theme.colorScheme.onPrimaryContainer));
    }
  }

  static BubbleStyle getStyle(bool isOwn) {
    return isOwn == true ? own : other;
  }
}

class BubbleStyle {
  final Color mainColor;
  final Color pressedColor;
  final TextStyle mainTextStyle;
  final TextStyle dateTextStyle;
  final FormatStyle textFormatStyle;

  static TextStyle getAuthorTextStyle(
      final ThemeData theme, final String author) {
    final double hue = HSLColor.fromColor(theme.colorScheme.primary).hue;
    late final double minHue;
    late final double maxHue;

    if (hue < 40) {
      minHue = hue;
      maxHue = hue + 40;
    } else if (hue > 320) {
      minHue = hue - 40;
      maxHue = hue;
    } else {
      minHue = hue - 40;
      maxHue = hue + 40;
    }

    double saturation = int.parse(author.hashCode.toString()[0]) * 0.1;
    if (saturation < 0.4) {
      saturation = 0.4;
    }

    final double lightness = theme.brightness == Brightness.dark ? 0.7 : 0.3;

    Color color = ColorHash(author,
            hue: (minHue, maxHue), saturation: saturation, lightness: lightness)
        .toColor();

    return theme.textTheme.labelLarge!.copyWith(color: color);
  }

  const BubbleStyle(
      {required this.mainColor,
      required this.pressedColor,
      required this.mainTextStyle,
      required this.dateTextStyle,
      required this.textFormatStyle});
}

void showSnackbar(final BuildContext context, final String text,
    {seconds = 1, milliseconds = 0}) {
  if (context.mounted) {
    // Hide the current SnackBar if one is already visible.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: Duration(seconds: seconds, milliseconds: milliseconds),
      ),
    );
  }
}
