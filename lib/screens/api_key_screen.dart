import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/openai_service.dart';
import 'chat_screen.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keyController = TextEditingController();
  final _db = DatabaseService();
  final _openAI = OpenAIService();

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final key = _keyController.text.trim();

    try {
      final valid = await _openAI.validateApiKey(key);
      if (!valid) {
        _showError('Invalid API key. Please check and try again.');
        return;
      }
      await _db.saveSetting('openai_api_key', key);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ChatScreen(apiKey: key)),
      );
    } catch (e) {
      _showError('Could not verify key: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo / Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 44,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to AI Chat',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your OpenAI API key to get started.\n'
                  'Your key is stored locally and never shared.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 36),

                // Form
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _keyController,
                    obscureText: _obscure,
                    keyboardType: TextInputType.visiblePassword,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API Key',
                      hintText: 'sk-...',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'API key is required';
                      }
                      if (!v.trim().startsWith('sk-')) {
                        return 'Key should start with "sk-"';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveKey,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Continue', style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Open OpenAI platform URL – user copies it manually
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Get your key at: https://platform.openai.com/api-keys',
                        ),
                      ),
                    );
                  },
                  child: const Text("Don't have a key? Get one here"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
