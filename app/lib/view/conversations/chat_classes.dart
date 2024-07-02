import 'dart:math';

import 'package:flutter/material.dart';
import 'package:color_hash/color_hash.dart';
import 'package:flutter_chat_bubble/bubble_type.dart';
import 'package:flutter_chat_bubble/clippers/chat_bubble_clipper_1.dart';
import 'package:sph_plan/shared/widgets/format_text.dart';

class ConversationSettings {
  final String id; // uniqueId
  final bool groupChat;
  final bool onlyPrivateAnswers;
  final bool noReply;
  final bool own;
  final String? author;

  const ConversationSettings({required this.id, required this.groupChat, required this.onlyPrivateAnswers, required this.noReply, required this.own, this.author});
}

class Message {
  final String text;
  final bool own;
  final String? author;
  final DateTime date;
  final MessageState state;
  MessageStatus status;

  Message({required this.text, required this.own, required this.date, required this.author, required this.state, required this.status});
}

enum MessageStatus {
  sending(Icons.pending),
  sent(Icons.check_circle),
  error(Icons.error);

  final IconData icon;

  const MessageStatus(this.icon);
}

enum MessageState {
  first,
  series;
}

class DateHeader {
  final DateTime date;
  const DateHeader({required this.date});
}

class AuthorHeader {
  final String author;
  const AuthorHeader({required this.author});
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
        nipRadius: 4
    );
  }

  static EdgeInsets getPadding(final bool nipCompensation, final bool own) {
    final double margin = nipCompensation ? compensatedPadding : horizontalPadding;

    return EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: own ? horizontalPadding : margin,
        right: own ? margin : horizontalPadding
    );
  }

  static EdgeInsets getMargin(final MessageState state) {
    final double combinedMargin = state == MessageState.first ? horizontalMargin : horizontalMargin + nipWidth;

    return EdgeInsets.only(
        left: combinedMargin,
        right: combinedMargin,
        top: state == MessageState.first ? 8.0 : 2.0
    );
  }
}

class BubbleStyle {
  late final Color color;
  late final TextStyle textStyle;
  late final TextStyle dateTextStyle;

  static final Random random = Random();

  static TextStyle getAuthorTextStyle(final BuildContext context, final String author) {
    final double hue = HSLColor.fromColor(Theme.of(context).colorScheme.primary).hue;
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

    final double lightness = Theme.of(context).brightness == Brightness.dark ? 0.7 : 0.3;

    Color color = ColorHash(author, hue: (minHue, maxHue), saturation: saturation, lightness: lightness).toColor();

    return Theme.of(context).textTheme.labelLarge!.copyWith(color: color);
  }

  static Color getColor(final BuildContext context, final bool own) {
    if (own) {
      return Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryFixedDim;
    } else {
      return Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.secondaryFixed;
    }
  }

  static Color getPressedColor(final BuildContext context, final bool own) {
    if (own) {
      return Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.primaryFixed : Theme.of(context).colorScheme.primaryFixed;
    } else {
      return Theme.of(context).brightness == Brightness.dark ? Theme.of(context).colorScheme.secondaryFixed : Theme.of(context).colorScheme.surfaceContainerHigh;
    }
  }

  static TextStyle getTextStyle(final BuildContext context, final bool own) {
    final TextStyle textStyle = Theme.of(context).textTheme.bodyMedium!;

    if (own) {
      return Theme.of(context).brightness == Brightness.dark ? textStyle.copyWith(color: Theme.of(context).colorScheme.onPrimary, decorationColor: Theme.of(context).colorScheme.onPrimary)
          : textStyle.copyWith(color: Theme.of(context).colorScheme.onPrimaryFixedVariant, decorationColor: Theme.of(context).colorScheme.onPrimaryFixedVariant);
    } else {
      return Theme.of(context).brightness == Brightness.dark ? textStyle.copyWith(color: Theme.of(context).colorScheme.onSecondary, decorationColor: Theme.of(context).colorScheme.onSecondary)
          : textStyle.copyWith(color: Theme.of(context).colorScheme.onSecondaryFixed, decorationColor: Theme.of(context).colorScheme.onSecondaryFixed);
    }
  }

  static TextStyle getDateTextStyle(final BuildContext context) => Theme.of(context).textTheme.bodySmall!.copyWith(color: Theme.of(context).colorScheme.onSurface);

  static FormatStyle getFormatStyle(final BuildContext context, final bool own) {
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;

    if (own) {
      return FormatStyle(
          textStyle: BubbleStyle.getTextStyle(context, own),
          timeColor: darkMode ? Theme.of(context).colorScheme.inversePrimary : Theme.of(context).colorScheme.primary,
          linkBackground: darkMode ? Theme.of(context).colorScheme.inversePrimary.withOpacity(0.25) : Theme.of(context).colorScheme.primary.withOpacity(0.25),
          linkForeground: darkMode ? Theme.of(context).colorScheme.inversePrimary : Theme.of(context).colorScheme.primary,
          codeBackground: darkMode ? Theme.of(context).colorScheme.secondaryFixed.withOpacity(0.4) :  Theme.of(context).colorScheme.secondaryFixed.withOpacity(0.4),
          codeForeground: darkMode ? Theme.of(context).colorScheme.onSecondaryFixed : Theme.of(context).colorScheme.onSecondaryFixed
      );
    } else {
      return FormatStyle(
          textStyle: BubbleStyle.getTextStyle(context, own),
          timeColor: darkMode ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.primary.withOpacity(0.75),
          linkBackground: darkMode ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35) : Theme.of(context).colorScheme.primaryFixedDim.withOpacity(0.75),
          linkForeground: darkMode ? Theme.of(context).colorScheme.secondaryContainer : Theme.of(context).colorScheme.primary,
          codeBackground: darkMode ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.15) : Theme.of(context).colorScheme.secondaryFixedDim.withOpacity(0.75),
          codeForeground: darkMode ? Theme.of(context).colorScheme.onSecondary : Theme.of(context).colorScheme.onSecondaryFixedVariant
      );
    }
  }
}