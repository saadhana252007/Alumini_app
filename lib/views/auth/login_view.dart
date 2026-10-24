import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../viewmodels/session_viewmodel.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});
  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final o = await ref
        .read(loginViewModelProvider.notifier)
        .submit(_email.text, _password.text);
    if (!mounted) return;
    if (!o.ok) showError(context, o.error!);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(loginViewModelProvider).busy;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final formCard = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: AutofillGroup(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!wide) ...[
                const Center(child: BrandMark(size: 64, onDark: false)),
                const SizedBox(height: 16),
              ],
              Text('Administrator sign in',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.navy)),
              const SizedBox(height: 6),
              const Text(
                'Access is limited to authorised administrators. Accounts are '
                'created by the Super Admin; self-registration is disabled.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: 'Institute e-mail'),
                validator: (v) => (v == null || !v.contains('@')) ? 'Enter your e-mail' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign in'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    return Scaffold(
      body: wide
          ? Row(children: [
              Expanded(
                flex: 5,
                child: Container(
                  color: AppColors.navy,
                  padding: const EdgeInsets.all(48),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const BrandMark(size: 84),
                    const SizedBox(height: 28),
                    Text('Indian Institute of Technology\n(Indian School of Mines), Dhanbad',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, height: 1.25)),
                    const SizedBox(height: 14),
                    Container(width: 72, height: 3, color: AppColors.gold),
                    const SizedBox(height: 14),
                    const Text('Institutional Administration Portal\nExecutive Development Centre - Accommodation',
                        style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
                  ]),
                ),
              ),
              Expanded(flex: 4, child: Center(child: SingleChildScrollView(child: formCard))),
            ])
          : Center(child: SingleChildScrollView(child: formCard)),
    );
  }
}
