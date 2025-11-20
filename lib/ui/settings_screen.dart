import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiController = TextEditingController();
  final _rapidApiController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscureGemini = true;
  bool _obscureRapid = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _rapidApiController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final geminiKey = await SettingsService.getGeminiApiKey();
      final rapidKey = await SettingsService.getRapidApiKey();
      
      if (geminiKey != null) _geminiController.text = geminiKey;
      if (rapidKey != null) _rapidApiController.text = rapidKey;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await SettingsService.setGeminiApiKey(_geminiController.text.trim());
      await SettingsService.setRapidApiKey(_rapidApiController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save Settings',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Card(
                      color: colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Icon(Icons.key, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'API Configuration',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Configure your API keys to enable recipe extraction',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Gemini API Key
                    Text(
                      'Gemini API Key',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _geminiController,
                      obscureText: _obscureGemini,
                      decoration: InputDecoration(
                        hintText: 'Enter your Gemini API key',
                        prefixIcon: const Icon(Icons.vpn_key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureGemini ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureGemini = !_obscureGemini);
                          },
                        ),
                        helperText: 'Get your key from ai.google.dev',
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Gemini API key is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // RapidAPI Key
                    Text(
                      'RapidAPI Key',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _rapidApiController,
                      obscureText: _obscureRapid,
                      decoration: InputDecoration(
                        hintText: 'Enter your RapidAPI key',
                        prefixIcon: const Icon(Icons.cloud),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureRapid ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureRapid = !_obscureRapid);
                          },
                        ),
                        helperText: 'Get your key from rapidapi.com',
                        helperMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'RapidAPI key is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),

                    // Instructions Card
                    Card(
                      color: colorScheme.surfaceVariant,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  'How to get API keys',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInstruction('1', 'Gemini API: Visit ai.google.dev/gemini-api'),
                            const SizedBox(height: 8),
                            _buildInstruction('2', 'RapidAPI: Visit rapidapi.com and subscribe to Instagram API'),
                            const SizedBox(height: 8),
                            _buildInstruction('3', 'Copy your keys and paste them above'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isLoading ? null : _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Configuration'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInstruction(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            number,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
