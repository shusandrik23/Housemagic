import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/catalog.dart';
import '../../core/theme.dart';
import '../../state/session_controller.dart';
import '../child/child_mode_screen.dart';
import '../family/family_screen.dart';
import '../shopping/shopping_screen.dart';
import '../today/today_screen.dart';

/// Главный разворот взрослого: «Сегодня», «Покупки», «Семья и Домик».
/// В детском режиме вместо него показывается «Академия Юных Хранителей».
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    if (session.inChildMode) {
      final child = session.activeChild;
      if (child == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return ChildModeScreen(key: ValueKey(child.id), child: child);
    }
    final household = session.household!;
    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: const [ProfileSwitcher(), SizedBox(width: 8)],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [TodayScreen(), ShoppingScreen(), FamilyScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Pen.paper,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Сегодня'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Покупки'),
          NavigationDestination(icon: Icon(Icons.family_restroom), label: 'Семья и Домик'),
        ],
      ),
    );
  }
}

/// Переключатель профиля в шапке: взрослый ↔ карточки детей.
class ProfileSwitcher extends StatelessWidget {
  const ProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final me = session.me;
    return PopupMenuButton<String>(
      key: const ValueKey('profile-switcher'),
      tooltip: 'Сменить профиль',
      onSelected: (value) async {
        if (value == '__signout') {
          await session.signOut();
        } else if (value.startsWith('child:')) {
          await session.enterChildMode(value.substring(6));
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            '${Catalog.petEmoji(me?.petType)} ${session.displayName} (взрослый)',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Pen.blue),
          ),
        ),
        if (session.childProfiles.isNotEmpty) const PopupMenuDivider(),
        for (final c in session.childProfiles)
          PopupMenuItem<String>(
            value: 'child:${c.id}',
            child: Text('${Catalog.petEmoji(c.petType)} ${c.name} — детский режим'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: '__signout', child: Text('Выйти из аккаунта')),
      ],
      child: Chip(
        avatar: Text(Catalog.petEmoji(me?.petType)),
        label: Text(session.displayName, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
