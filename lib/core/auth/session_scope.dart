import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../dashboards/current_dashboard.dart';
import '../database/local_database.dart';
import 'current_account.dart';
import '../dashboards/dashboard_switch.dart';

/// Estado de sesión con el que arranca un contenedor nuevo (después de cerrar sesión o de cambiar
/// de dashboard), en lugar de volver a consultar el almacenamiento. null = arranque normal de la app.
final initialAuthStateProvider = Provider<AuthState?>((ref) => null);

/// Raíz de providers de la app. Descarta TODO el contenedor y crea uno nuevo cuando:
///  - la sesión deja de estar autenticada (cierre de sesión o sesión expirada): ningún provider
///    conserva datos del usuario anterior; su base local se cierra pero no se borra;
///  - cambia el dashboard elegido ([CurrentDashboard]): ningún provider conserva datos del dashboard
///    anterior y el contenedor nuevo abre la base local del elegido.
/// El contenedor nuevo arranca con el estado de sesión ya resuelto.
class SessionScope extends StatefulWidget {
  final Widget child;

  /// Solo para tests.
  final List<Override> overrides;

  const SessionScope({super.key, required this.child, this.overrides = const []});

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  ProviderContainer? _container;
  ProviderSubscription<AuthState>? _auth;
  var _wasAuthenticated = false;

  /// Usuario al que pertenece la elección guardada (para descartarla si inicia sesión otro).
  int? _choiceOwner;

  /// El cambio de dashboard lo provoca el propio cierre de sesión: no hay que recrear dos veces.
  var _resetting = false;

  @override
  void initState() {
    super.initState();
    CurrentDashboard.id.addListener(_onDashboardChanged);
    // La elección guardada se aplica antes de crear el contenedor: nada abre otra base primero.
    CurrentDashboard.restore().then((owner) {
      if (!mounted) return;
      _choiceOwner = owner;
      setState(() => _container = _create(null));
    });
  }

  ProviderContainer _create(AuthState? initial) {
    final c = ProviderContainer(overrides: [
      ...widget.overrides,
      if (initial != null) initialAuthStateProvider.overrideWithValue(initial),
    ]);
    _wasAuthenticated = false;
    _auth = c.listen<AuthState>(authNotifierProvider, (_, next) {
      if (next.isAuthenticated) {
        _wasAuthenticated = true;
        final userId = next.user?.idUsuario;
        DashboardSwitch.userId = userId;
        CurrentAccount.id = userId; // sus bases y datos locales (cada cuenta tiene los suyos)
        // La elección guardada era de otro usuario: vuelve a su principal.
        if (_choiceOwner != null && userId != null && _choiceOwner != userId) {
          _choiceOwner = userId;
          if (CurrentDashboard.id.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => DashboardSwitch.select(null));
        }
      } else if (_wasAuthenticated && (next.status == AuthStatus.unauthenticated || next.status == AuthStatus.error)) {
        _reset(next);
      }
    }, fireImmediately: true);
    return c;
  }

  void _onDashboardChanged() {
    final current = _container;
    if (_resetting || current == null || !_wasAuthenticated) return;
    _replace(current.read(authNotifierProvider));
  }

  void _reset(AuthState state) {
    _resetting = true;
    DashboardSwitch.userId = null;
    // Se cierra la base de la cuenta que salió; sus datos y pendientes quedan en el celular.
    CurrentAccount.id = null;
    unawaited(LocalDatabase.close());
    _choiceOwner = null;
    CurrentDashboard.id.value = null; // el próximo inicio de sesión arranca en su principal
    _resetting = false;
    _replace(state);
  }

  void _replace(AuthState state) {
    final old = _container;
    _auth?.close();
    setState(() => _container = _create(state));
    // El árbol viejo se desmonta en este frame: recién después se libera su contenedor.
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    CurrentDashboard.id.removeListener(_onDashboardChanged);
    _auth?.close();
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    if (container == null) return const SizedBox.shrink();
    return UncontrolledProviderScope(key: ObjectKey(container), container: container, child: widget.child);
  }
}
