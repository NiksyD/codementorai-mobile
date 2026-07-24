import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/supabase_auth_repository.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    this.authRepository = const SupabaseAuthRepository(),
  });

  final AuthRepository authRepository;

  Future<void> _handleSignOut(BuildContext context) async {
    await authRepository.signOut();
    if (!context.mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.dashboard_customize_outlined,
                size: 80.0,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24.0),
              Text(
                'Welcome to CodeMentor AI',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12.0),
              Text(
                'Your AI mentorship workspace is ready. You are securely authenticated.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32.0),
              ElevatedButton.icon(
                onPressed: () => _handleSignOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
