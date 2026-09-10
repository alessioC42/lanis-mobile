import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'account_tile.dart';

class AccountSwitcher extends ConsumerStatefulWidget {
  const AccountSwitcher({super.key});

  @override
  ConsumerState<AccountSwitcher> createState() => _AccountSwitcherState();
}

class _AccountSwitcherState extends ConsumerState<AccountSwitcher> {
  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final active = ref.watch(activeAccountProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).switchAccount)),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (accounts) {
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AccountTile(
                account: account,
                lastLogin: account.lastLogin ?? DateTime.now(),
                onTap: () async {
                  if (active?.localId == account.localId) {
                    context.pop();
                    return;
                  }
                  final ok = await ref
                      .read(authControllerProvider.notifier)
                      .loginWithAccount(account.localId);
                  if (!context.mounted) return;
                  if (ok) {
                    context.go(firstSupportedHomePath(ref));
                  }
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.push('/login'),
        label: Text(AppLocalizations.of(context).addAccount),
        icon: Icon(Icons.person_add),
      ),
    );
  }
}
