import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/error_messages.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_state.dart';
import '../../../../l10n/l10n.dart';
import '../../../../core/constants/app_info.dart';

/// Correo con '@' y '.'; null si es válido.
@visibleForTesting
String? validarEmail(String? val, AppLocalizations l) {
  final v = val?.trim() ?? '';
  if (v.isEmpty) return l.enterEmail;
  return v.contains('@') && v.contains('.') ? null : l.invalidEmail;
}

/// La contraseña solo tiene que estar (los espacios pueden ser parte de ella).
@visibleForTesting
String? validarPassword(String? val, AppLocalizations l) => val == null || val.isEmpty ? l.enterPassword : null;

/// Aviso de por qué se volvió al login: sesión vencida, o se cerró en el celular pero el servidor no la revocó.
@visibleForTesting
String? avisoDeSesion(AuthState state, AppLocalizations l) {
  final detalle = state.noticeError;
  return switch (state.notice) {
    AuthNotice.sessionExpired => l.sessionExpiredPleaseSignAgain,
    AuthNotice.logoutNotRevoked => l.signedOutDeviceButServer(detalle == null ? '' : ' (${ErrorMessages.describe(detalle, l)})'),
    null => null,
  };
}

class LoginScreen extends ConsumerStatefulWidget {
  /// Servidor fijado al compilar ([ApiConfig.baseUrl]); en los tests se indica acá. null = el compilado.
  final String? servidor;

  const LoginScreen({super.key, this.servidor});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscurePassword = true;

  String get _servidor => (widget.servidor ?? ApiConfig.baseUrl).trim();

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    // La contraseña se envía tal cual: los espacios pueden ser parte de ella.
    final ok = await ref.read(authNotifierProvider.notifier).login(_emailController.text.trim(), _passController.text);
    if (ok || !mounted) return;
    final error = ref.read(authNotifierProvider).error;
    if (error != null) _showError(error);
  }

  void _showError(Object error) {
    final code = ErrorMessages.codeOf(error);
    final message = ErrorMessages.describe(error, context.l10n);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(code == null ? message : '$message\n${context.l10n.code}: $code', style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notice = avisoDeSesion(authState, l10n);
    final configurada = _servidor.isNotEmpty;
    const etiqueta = TextStyle(fontWeight: FontWeight.w600, fontSize: 13);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 28),
                    if (!configurada) _Banner(color: AppColors.rose, icon: Icons.dns_outlined, text: ErrorMessages.forCode('CONFIG_MISSING', '', l10n)),
                    if (notice != null) _Banner(color: AppColors.amber, icon: Icons.info_outline_rounded, text: notice),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.sign, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 20),
                            const Text('Email', style: etiqueta),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const ValueKey('login-email'),
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(hintText: l10n.youExampleCom, prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20)),
                              validator: (val) => validarEmail(val, l10n),
                            ),
                            const SizedBox(height: 18),
                            Text(l10n.password, style: etiqueta),
                            const SizedBox(height: 6),
                            TextFormField(
                              key: const ValueKey('login-password'),
                              controller: _passController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submitLogin(),
                              decoration: InputDecoration(
                                hintText: '••••••••',
                                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (val) => validarPassword(val, l10n),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              key: const ValueKey('login-ingresar'),
                              onPressed: authState.isLoading || !configurada ? null : _submitLogin,
                              child: authState.isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                    )
                                  : Text(l10n.sign2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        _servidor,
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, size: 42, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
        ],
      );
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _Banner({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
