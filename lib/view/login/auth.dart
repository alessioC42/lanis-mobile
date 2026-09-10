import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/login/school_selector.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool showBackButton;
  const LoginForm({required this.showBackButton, super.key});

  @override
  ConsumerState<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends ConsumerState<LoginForm> {
  static const double padding = 10.0;

  final _formKey = GlobalKey<FormState>();

  TextEditingController schoolIDController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool dseAgree = false;
  bool errorReportingAgree = false;
  String selectedSchoolName = "";

  @override
  void initState() {
    super.initState();
    // Mirror the device-wide GlitchTip choice when adding another account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shared = ref.read(sharedOverAccountSettingsProvider);
      setState(() {
        errorReportingAgree = isGlitchTipEnabled(shared);
      });
    });
  }

  void login(String username, String password, String schoolID) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).logInTitle),
        content: const Center(
          heightFactor: 1.2,
          child: CircularProgressIndicator(),
        ),
      ),
    );
    try {
      final schoolId = int.parse(schoolID);
      final accounts = await ref.read(accountsProvider.future);
      if (accounts.any(
        (a) => a.schoolID == schoolId && a.username == username,
      )) {
        throw AccountAlreadyExistsException();
      }

      // Login checkbox is the first-time privacy acceptance for new accounts.
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);
      setGlitchTipEnabled(shared, errorReportingAgree);

      final config = ref.read(lanisConfigProvider);
      await LanisSession.getLoginURL(
        ClearTextAccount(
          localId: -1,
          schoolID: schoolId,
          username: username,
          password: password,
          schoolName: "",
        ),
        config,
      );

      final newID = await ref
          .read(accountsProvider.notifier)
          .add(
            schoolId: schoolId,
            username: username,
            password: password,
            schoolName: selectedSchoolName,
          );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(newID, removeAccountOnFailure: true);
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      if (ok) {
        context.go(firstSupportedHomePath(ref));
        return;
      }
      if (!mounted) return;
      final auth = ref.read(authControllerProvider);
      final cause =
          auth.exception?.cause ?? AppLocalizations.of(context).unknownError;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (ex, s) {
      logger.e(ex, stackTrace: s);

      String cause = "";
      if (ex is LanisException) {
        cause = ex.cause;
      } else {
        if (mounted) {
          cause = AppLocalizations.of(context).unknownError;
        }
      }

      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).error),
          content: Text(cause),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    schoolIDController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showBackButton)
          Padding(
            padding: EdgeInsets.only(right: 32, top: 32),
            child: IconButton(
              onPressed: () {
                // Welcome uses go('/login') (no stack); account switcher uses push.
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/welcome');
                }
              },
              icon: Icon(Icons.arrow_back),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(padding),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 550),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: padding),
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.person, size: 70),
                                Text(
                                  AppLocalizations.of(context).logIn,
                                  style: const TextStyle(fontSize: 35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: padding * 5),
                          SchoolSelector(
                            controller: schoolIDController,
                            outContext: context,
                            onSchoolSelected: (name) {
                              selectedSchoolName = name;
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: usernameController,
                            enabled: schoolIDController.text != "",
                            autofillHints: [AutofillHints.username],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authUsernameHint,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: passwordController,
                            enabled: schoolIDController.text.isNotEmpty,
                            autofillHints: [AutofillHints.password],
                            autocorrect: false,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authPasswordHint,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          Visibility(
                            child: ExcludeSemantics(
                              child: CheckboxListTile(
                                enabled: schoolIDController.text.isNotEmpty,
                                value: dseAgree,
                                title: RichText(
                                  text: TextSpan(
                                    text: AppLocalizations.of(
                                      context,
                                    ).authIAccept,
                                    style: DefaultTextStyle.of(context).style,
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: AppLocalizations.of(
                                          context,
                                        ).authTermsOfService,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => safeLaunchUrl(
                                            Uri.parse(privacyPolicyUrl),
                                            context: context,
                                          ),
                                      ),
                                      TextSpan(
                                        text: AppLocalizations.of(
                                          context,
                                        ).authOfLanisMobile,
                                      ),
                                    ],
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    dseAgree = val!;
                                  });
                                },
                              ),
                            ),
                          ),
                          Visibility(
                            child: ExcludeSemantics(
                              child: CheckboxListTile(
                                enabled: schoolIDController.text.isNotEmpty,
                                value: errorReportingAgree,
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).authErrorReportingOptional,
                                  style: DefaultTextStyle.of(context).style,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    errorReportingAgree = val!;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: padding),
                          FilledButton(
                            onPressed: dseAgree
                                ? () {
                                    if (_formKey.currentState!.validate()) {
                                      login(
                                        usernameController.text.toLowerCase(),
                                        passwordController.text,
                                        schoolIDController.text,
                                      );
                                    }
                                  }
                                : null,
                            child: Text(AppLocalizations.of(context).logIn),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: schoolIDController.text.isNotEmpty
                                    ? () => safeLaunchUrl(
                                        Uri.parse(
                                          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userPWreminder&i=${schoolIDController.text}",
                                        ),
                                        context: context,
                                      )
                                    : null,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).authResetPassword,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
