import 'package:flutter/material.dart';
import 'package:linkify/linkify.dart';
import 'package:styled_text/styled_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../client/logger.dart';

class FormatPattern {
  late final RegExp regExp;
  late final String? startTag;
  late final String? endTag;
  late final int group;
  late final Map<String, String> map;
  late final RegExp? specialCaseRegExp;
  late final String? specialCaseTag;
  late final List<int> specialCaseGroups;

  FormatPattern(
      {required this.regExp,
      this.startTag,
      this.endTag,
      this.group = 1,
      this.map = const {},
      this.specialCaseRegExp,
      this.specialCaseTag,
      this.specialCaseGroups = const [1]});
}

class FormatStyle {
  late final TextStyle textStyle;
  late final Color timeColor;
  late final Color linkBackground;
  late final Color linkForeground;
  late final Color codeBackground;
  late final Color codeForeground;

  FormatStyle({required this.textStyle,
    required this.timeColor,
    required this.linkBackground,
    required this.linkForeground,
    required this.codeBackground,
    required this.codeForeground});
}

class DefaultFormatStyle extends FormatStyle {
  late final BuildContext context;

  DefaultFormatStyle({required this.context}) : super(
    textStyle: Theme.of(context).textTheme.bodyMedium!,
    timeColor: Theme.of(context).colorScheme.primary,
    linkBackground: Theme.of(context).colorScheme.primary.withOpacity(0.25),
    linkForeground: Theme.of(context).colorScheme.primary,
    codeBackground: Theme.of(context).colorScheme.secondary.withOpacity(0.25),
    codeForeground: Theme.of(context).colorScheme.onSurface
  );
}

class FormattedText extends StatelessWidget {
  final String text;
  final FormatStyle formatStyle;
  const FormattedText({super.key, required this.text, required this.formatStyle});

  /// Replaces all occurrences of map keys with their respective value
  String convertByMap(String string, Map<String, String> map) {
    var str = string;
    for (var entry in map.entries) {
      str = str.replaceAll(entry.key, entry.value);
    }
    return str;
  }

  /// Converts Lanis-style formatting into pseudo-HTML using rules defined as in<br />
  /// https://support.schulportal.hessen.de/knowledgebase.php?article=664<br />
  ///<br />
  /// Implemented:<br />
  /// ** => <​b>,<br />
  /// __ => <​u>,<br />
  /// -- => <​i>,<br />
  /// ` or ``` => <​code>,<br />
  /// ​- => \u2022 (•),<br />
  /// _ and _() => character substitution subscript,<br />
  /// ^ and ^() => character substitution superscript,<br />
  /// 12.01.23, 12.01.2023 => <​date>,<br />
  /// 12:03 => <​time><br />
  String convertLanisSyntax(String lanisStyledText) {
    final List<FormatPattern> formatPatterns = [
      FormatPattern(
          regExp: RegExp(r"--(([^-]|-(?!-))+)--"),
          specialCaseRegExp: RegExp(r"--((|.*)__(([^_]|_(?!_))+)__(.*|))--"),
          specialCaseTag: "<del hasU=true>",
          specialCaseGroups: [2, 3, 5],
          startTag: "<del>",
          endTag: "</del>"),
      FormatPattern(
          regExp: RegExp(r"__(([^_]|_(?!_))+)__"),
          specialCaseRegExp: RegExp(r"__((|.*)--(([^-]|-(?!-))+)--(.*|))__"),
          specialCaseTag: "<u hasDel=true>",
          specialCaseGroups: [2, 3, 5],
          startTag: "<u>",
          endTag: "</u>"),
      FormatPattern(
          regExp: RegExp(r"\*\*(([^*]|\*(?!\*))+)\*\*"),
          startTag: "<b>",
          endTag: "</b>"),
      FormatPattern(
          regExp: RegExp(r"_\((.*?)\)"),
          startTag: "<sub>",
          endTag: "</sub>"),
      FormatPattern(
          regExp: RegExp(r"_(.)\s"),
          startTag: "<sub>",
          endTag: "</sub>"),
      FormatPattern(
          regExp: RegExp(r"\^\((.*?)\)"),
          startTag: "<sup>",
          endTag: "</sup>"),
      FormatPattern(
          regExp: RegExp(r"\^(.)\s"),
          startTag: "<sup>",
          endTag: "</sup>"),
      FormatPattern(
          regExp: RegExp(r"~~(([^~]|~(?!~))+)~~"),
          startTag: "<i>",
          endTag: "</i>"),
      FormatPattern(
          regExp: RegExp(r"`(?!``)(.*)(?<!``)`"),
          startTag: "<code>",
          endTag: "</code>"),
      FormatPattern(
          regExp: RegExp(r"```\n*((?:[^`]|`(?!``))*)\n*```"),
          startTag: "<code>",
          endTag: "</code>"),
      FormatPattern(
          regExp: RegExp(r"(\d{2}\.\d{1,2}\.(\d{4}|\d{2}\b))"),
          startTag: "<date>",
          endTag: "</date>"),
      FormatPattern(
          regExp:
              RegExp(r"(\d{2}:\d{2} Uhr)|(\d{2}:\d{2})", caseSensitive: false),
          startTag: "<time>",
          endTag: "</time>",
          group: 0),
      FormatPattern(
          regExp: RegExp(r"^[ \t]*-[ \t]*(.*)", multiLine: true),
          startTag: "\u2022 "),
    ];

    String formattedText = lanisStyledText;

    // Escape special characters so that StyledText doesn't use them for parsing.
    formattedText = formattedText.replaceAll("<", "&lt;");
    formattedText = formattedText.replaceAll(">", "&gt;");
    formattedText = formattedText.replaceAll("&", "&amp;");
    formattedText = formattedText.replaceAll('"', "&quot;");
    formattedText = formattedText.replaceAll("'", "&apos;");

    // Apply special case formatting, mainly for the 2 TextDecoration tags: .underline and .lineThrough
    // because without this always one of the TextDecoration exists, not both together.
    for (final FormatPattern pattern in formatPatterns) {
      if (pattern.specialCaseRegExp == null) break;
      formattedText = formattedText.replaceAllMapped(
          pattern.specialCaseRegExp!,
              (match) =>
          "${pattern.specialCaseTag ?? ""}${convertByMap(match.groups(pattern.specialCaseGroups).join(), pattern.map)}${pattern.endTag ?? ""}");
    }

    // Apply formatting
    for (final FormatPattern pattern in formatPatterns) {
      formattedText = formattedText.replaceAllMapped(
          pattern.regExp,
          (match) =>
              "${pattern.startTag ?? ""}${convertByMap(match.group(pattern.group)!, pattern.map)}${pattern.endTag ?? ""}");
    }
    
    // Surround emails and links with <a> tag
    final List<LinkifyElement> linkifiedElements = linkify(formattedText,
        options: const LinkifyOptions(humanize: true, removeWww: true),
        linkifiers: const [EmailLinkifier(), UrlLinkifier()]);

    String linkifiedText = "";

    for (LinkifyElement element in linkifiedElements) {
      if (element is UrlElement) {
        linkifiedText +=
            "<a href='${element.url}' type='url'>${element.text}</a>";
      } else if (element is EmailElement) {
        linkifiedText +=
            "<a href='${element.url}' type='email'>${element.text}</a>";
      } else {
        linkifiedText += element.text;
      }
    }

    return linkifiedText;
  }

  @override
  Widget build(BuildContext context) {
    return StyledText(
      text: convertLanisSyntax(text),
      style: formatStyle.textStyle,
      tags: {
        "b": const StyledTextTag(style: TextStyle(fontWeight: FontWeight.bold)),
        "u": StyledTextCustomTag(
            parse: (_, attributes) {
              List<TextDecoration> textDecorations = [TextDecoration.underline];
              if (attributes.containsKey("hasDel")) textDecorations.add(TextDecoration.lineThrough);

              return TextStyle(
                decoration: TextDecoration.combine(textDecorations),
              );
            }
        ),
        "i": const StyledTextTag(style: TextStyle(fontStyle: FontStyle.italic)),
        "del": StyledTextCustomTag(
          parse: (_, attributes) {
            List<TextDecoration> textDecorations = [TextDecoration.lineThrough];
            if (attributes.containsKey("hasU")) textDecorations.add(TextDecoration.underline);

            return TextStyle(
                decoration: TextDecoration.combine(textDecorations),
            );
          }
        ),
        "sup": const StyledTextTag(
          style: TextStyle(fontFeatures: [FontFeature.superscripts()])
        ),
        "sub": const StyledTextTag(
            style: TextStyle(fontFeatures: [FontFeature.subscripts()])
        ),
        "code": StyledTextWidgetBuilderTag((context, _, textContent) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Container(
                padding: const EdgeInsets.only(
                    left: 8.0, right: 8.0, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color:
                  formatStyle.codeBackground,
                ),
                child: Text(
                  textContent!,
                  style: TextStyle(
                    fontFamily: "Roboto Mono",
                    color: formatStyle.codeForeground
                  ),
                ),
              ),
            )),
        "date": StyledTextWidgetBuilderTag((context, _, textContent) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.calendar_today,
                      size: 20, color: formatStyle.timeColor),
                ),
                Flexible(
                  child: Text(
                    textContent!,
                    style: TextStyle(
                        color: formatStyle.timeColor,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )),
        "time": StyledTextWidgetBuilderTag((context, _, textContent) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.access_time_filled,
                      size: 20, color: formatStyle.timeColor),
                ),
                Flexible(
                  child: Text(
                    textContent!,
                    style: TextStyle(
                        color: formatStyle.timeColor,
                        fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )),
        "a": StyledTextWidgetBuilderTag((context, attributes, textContent) {
          late final Icon icon;

          if (attributes["type"] == "url") {
            icon =
                Icon(Icons.link, color: formatStyle.linkForeground);
          } else {
            icon = Icon(Icons.email_rounded,
                color: formatStyle.linkForeground);
          }

          return Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: InkWell(
              onTap: () async {
                if (!await launchUrl(Uri.parse(attributes["href"]!))) {
                  logger.w('${attributes["href"]} konnte nicht geöffnet werden.');
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                  padding: const EdgeInsets.only(
                      left: 7, right: 8, top: 2, bottom: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: formatStyle.linkBackground,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: icon,
                      ),
                      Flexible(
                        child: Text(
                          textContent!,
                          style: TextStyle(
                              color: formatStyle.linkForeground),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  )),
            ),
          );
        }),
      },
    );
  }
}
