import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';

/// Blocking screen shown until the current [privacyPolicyPublishedAt] is accepted.
class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);

      // Bootstrap first so empty-account installs leave AuthPhase.unauthenticated
      // (otherwise /welcome is bounced back to /startup while still authenticating).
      await ref.read(authControllerProvider.notifier).bootstrapIfNeeded();
      if (!mounted) return;

      final accounts = await ref.read(accountsProvider.future);
      if (!mounted) return;
      if (accounts.isEmpty) {
        context.go('/welcome');
        return;
      }

      final auth = ref.read(authControllerProvider);
      if (auth.phase == AuthPhase.authenticated) {
        context.go(firstSupportedHomePath(ref));
      } else {
        context.go('/startup');
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Icon(
                  Icons.privacy_tip_outlined,
                  size: 72,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.privacyPolicyGateTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.privacyPolicyGateBody,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => safeLaunchUrl(
                    Uri.parse(privacyPolicyUrl),
                    context: context,
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.privacyPolicyGateOpen),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _accepting ? null : _accept,
                  child: _accepting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.privacyPolicyGateAccept),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
