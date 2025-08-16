import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:async_button_builder/async_button_builder.dart';
import 'package:veelog/providers/auth_provider.dart';

class AuthScreen extends HookConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final showPrivateKeyInput = useState(false);
    final privateKeyController = useTextEditingController();

    // Listen for authentication success
    ref.listen(authProvider, (previous, next) {
      if (next.isAuthenticated) {
        // Navigation will be handled by router
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF8B4513), // Wood brown background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo and title
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2B48C), // Tan wood color
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '🪵',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'VeeLog',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: const Color(0xFF654321), // Dark wood
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nostr Video Logging',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF8B4513), // Medium wood
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Error message
              if (authState.error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authState.error!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => ref.read(authProvider.notifier).clearError(),
                        color: Colors.red[700],
                      ),
                    ],
                  ),
                ),

              // Sign in with Amber button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: AsyncButtonBuilder(
                  onPressed: authState.isLoading ? null : () async {
                    await ref.read(authProvider.notifier).signInWithAmber();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.security, color: Colors.white),
                      const SizedBox(width: 12),
                      const Text('Sign in with Amber', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                  builder: (context, child, callback, buttonState) {
                    return ElevatedButton(
                      onPressed: callback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF654321), // Dark wood
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: buttonState.when(
                        idle: () => child,
                        loading: () => const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Connecting to Amber...'),
                          ],
                        ),
                        success: () => const Text('Success!'),
                        error: (error, stackTrace) => const Text('Failed'),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Development mode toggle
              TextButton(
                onPressed: () {
                  showPrivateKeyInput.value = !showPrivateKeyInput.value;
                  privateKeyController.clear();
                  ref.read(authProvider.notifier).clearError();
                },
                child: Text(
                  showPrivateKeyInput.value 
                      ? 'Hide Developer Options' 
                      : 'Developer Options',
                  style: TextStyle(
                    color: const Color(0xFFD2B48C), // Tan
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              // Private key input (collapsed by default)
              if (showPrivateKeyInput.value) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Development Only',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Private keys are stored in memory only. Use Amber for production.',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextField(
                  controller: privateKeyController,
                  decoration: InputDecoration(
                    labelText: 'Private Key (nsec...)',
                    hintText: 'nsec1...',
                    filled: true,
                    fillColor: const Color(0xFFD2B48C).withValues(alpha: 0.2),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: const Color(0xFF654321)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: const Color(0xFF654321), width: 2),
                    ),
                  ),
                  obscureText: true,
                  style: const TextStyle(color: Color(0xFF654321)),
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: AsyncButtonBuilder(
                    onPressed: authState.isLoading ? null : () async {
                      if (privateKeyController.text.trim().isNotEmpty) {
                        await ref.read(authProvider.notifier).signInWithPrivateKey(
                          privateKeyController.text.trim(),
                        );
                      }
                    },
                    child: const Text('Sign in with Private Key'),
                    builder: (context, child, callback, buttonState) {
                      return ElevatedButton(
                        onPressed: callback,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B4513), // Medium wood
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: buttonState.when(
                          idle: () => child,
                          loading: () => const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Signing in...'),
                            ],
                          ),
                          success: () => const Text('Success!'),
                          error: (error, stackTrace) => const Text('Failed'),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Info text
              Text(
                'Sign in to start sharing your video logs with the Nostr community',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD2B48C), // Tan
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}