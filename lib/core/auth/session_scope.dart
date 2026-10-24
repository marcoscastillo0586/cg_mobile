import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/auth_state.dart';

/// Estado de sesión con el que arranca un contenedor nuevo (después de cerrar sesión), en lugar
/// de volver a consultar el almacenamiento. null = arranque normal de la app.
final initialAuthStateProvider = Provider<AuthState?>((ref) => null);

/// Raíz de providers de la app. Cuando la sesión deja de estar autenticada (cierre de sesión o
/// sesión expirada) descarta TODO el contenedor y crea uno nuevo: ningún provider conserva datos
/// del usuario anterior en memoria ni la base local ya cerrada y borrada. El contenedor nuevo
/// arranca con el estado de sesión ya resuelto (incluido el aviso de logout sin red).
class SessionScope extends StatefulWidget {
  final Widget child;

  /// Solo para tests.
  final List<Override> overrides;

  const SessionScope({super.key, required this.child, this.overrides = const []});

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late ProviderContainer _container;
  ProviderSubscription<AuthState>? _auth;
  var _wasAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _container = _create(null);
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
      } else if (_wasAuthenticated && (next.status == AuthStatus.unauthenticated || next.status == AuthStatus.error)) {
        _reset(next);
      }
    }, fireImmediately: true);
    return c;
  }

  void _reset(AuthState state) {
    final old = _container;
    _auth?.close();
    setState(() => _container = _create(state));
    // El árbol viejo se desmonta en este frame: recién después se libera su contenedor.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _auth?.close();
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UncontrolledProviderScope(key: ObjectKey(_container), container: _container, child: widget.child);
}
