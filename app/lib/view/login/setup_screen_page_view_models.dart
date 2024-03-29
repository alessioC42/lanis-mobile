import 'dart:io';

import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sph_plan/shared/account_types.dart';
import 'package:sph_plan/shared/widgets/substitutions/substitutions_listtile.dart';
import 'package:sph_plan/view/settings/subsettings/notifications.dart';
import 'package:sph_plan/view/settings/subsettings/theme_changer.dart';

import '../../client/client.dart';
import '../../shared/apps.dart';
import '../vertretungsplan/filtersettings.dart';

final _klassenStufeController = TextEditingController();
final _klassenController = TextEditingController();
final _lehrerKuerzelController = TextEditingController();

List<PageViewModel> setupScreenPageViewModels = [
  //todo @codespoof
  if (client.getAccountType() != AccountType.student)
    PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_profile_re_4a55.svg",
            height: 175.0),
        title: "nicht-Schüleraccount",
        body:
            "Du hast offenbar einen nicht-Schüleraccount. Du kannst die App trotzdem verwenden, aber es kann sein, dass einige Features nicht funktionieren."),
  if (client.doesSupportFeature(SPHAppEnum.vertretungsplan)) ...[
    PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_filter_re_sa16.svg",
            height: 175.0),
        title: "Vertretungen filtern",
        body:
            "Damit du die Vertretungen, die für dich bestimmt sind, schneller finden kannst, gibt es ein Filter-Feature! Der Filter sucht in den Einträgen nach deiner Klassenstufe, Klasse und Lehrer des Faches. Damit du mit dem Filter (und dem Anzeigen der Vertretungen) die bestmögliche Erfahrung hast, muss die Schule die Einträge vollständig angeben, z. B. haben manche Schulen nicht die Lehrer der Fächer in ihren Einträgen richtig angegeben und geben stattdessen die Vertretung oder nichts an."),
    PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_wireframing_re_q6k6.svg",
            height: 175.0),
        title: "Beispiele für Einträge",
        bodyWidget: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 2.0),
              child: Text(
                "Beispiel für einen vollständigen Eintrag",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: SubstitutionListTile(substitutionData: {
                "Stunde": "1 - 2",
                "Klasse": "Q3/4",
                "Vertreter": "KAP",
                "Lehrer": "GIP",
                "Raum": "E1.14",
                "Fach": "D",
                "Art": "Vertretung"
              }),
            ),
            Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 2.0),
              child: Text(
                "Beispiel für einen unvollständigen Eintrag",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Card(
              child: SubstitutionListTile(substitutionData: {
                "Stunde": "1 - 2",
                "Vertreter": "KAP",
                "Hinweis": "Fällt aus"
              }),
            ),
            Text(
              "Wenn du solche Einträge siehst, solltest du dich an deine Schulleitung/Schul-IT wenden, um dieses Problem zu lösen.",
            ),
          ],
        )),
    PageViewModel(
        image: SvgPicture.asset("assets/undraw/undraw_settings_re_b08x.svg",
            height: 175.0),
        title: "Filtereinstellungen",
        bodyWidget: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilterElements(
              klassenStufeController: _klassenStufeController,
              klassenController: _klassenController,
              lehrerKuerzelController: _lehrerKuerzelController,
            )
          ],
        )),
    if (Platform.isIOS)
      PageViewModel(
          image: SvgPicture.asset(
              "assets/undraw/undraw_new_notifications_re_xpcv.svg",
              height: 175.0),
          title: "Benachrichtigungen",
          body:
              "Benachrichtigungen werden für dich leider nicht unterstützt, da Apple es nicht ermöglicht, dass Apps periodisch im Hintergrund laufen. Du kannst aber die App öffnen, um zu sehen, ob es neue Vertretungen gibt."),
    if (Platform.isAndroid) ...[
      PageViewModel(
          image: SvgPicture.asset(
              "assets/undraw/undraw_new_notifications_re_xpcv.svg",
              height: 175.0),
          title: "Benachrichtigungen",
          body:
              "Mit Benachrichtigungen weißt du direkt, ob und welche Vertretungen es für dich gibt. Du kannst auch einstellen wie oft die App nach neuen Vertretungen checkt, aber manchmal wird das Checken durch aktivierten Energiesparmodus oder anderen Faktoren verhindert."),
      PageViewModel(
          image: SvgPicture.asset(
              "assets/undraw/undraw_active_options_re_8rj3.svg",
              height: 175.0),
          title: "Benachrichtigungseinstellungen",
          bodyWidget: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [NotificationElements()],
          )),
    ]
  ],
  PageViewModel(
      image: SvgPicture.asset("assets/undraw/undraw_add_color_re_buro.svg",
          height: 175.0),
      title: "Aussehen",
      bodyWidget: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [AppearanceElements()],
      )),
  PageViewModel(
      image: SvgPicture.asset("assets/undraw/undraw_access_account_re_8spm.svg",
          height: 175.0),
      title: "Du bist jetzt bereit!",
      body:
          "Du kannst lanis-mobile jetzt verwenden. Wenn die App dir gefällt, kannst du gerne eine Bewertung im Play Store machen."),
];
