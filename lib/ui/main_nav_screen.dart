import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../providers/place_provider.dart';
import '../providers/recipe_provider.dart';
import 'home_screen.dart';
import 'places_home_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  final TextEditingController _urlController = TextEditingController();

  final List<Widget> _screens = [
    const HomeScreen(),
    const PlacesHomeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApiKeys());
    
    // Only use receive_sharing_intent on mobile platforms where it's implemented
    if (Platform.isAndroid || Platform.isIOS) {
      // Handle shared URLs when app is already running
      ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        if (value.isNotEmpty && value.first.type == SharedMediaType.text) {
          final sharedText = value.first.path;
          setState(() {
            _urlController.text = sharedText;
          });
          _showContentTypeDialog(sharedText);
        }
      }, onError: (err) {
        debugPrint('Error receiving shared data: $err');
      });

      // Handle shared URLs when app is launched from share
      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty && value.first.type == SharedMediaType.text) {
          final sharedText = value.first.path;
          setState(() {
            _urlController.text = sharedText;
          });
          _showContentTypeDialog(sharedText);
          // Reset to avoid processing the same intent again
          ReceiveSharingIntent.instance.reset();
        }
      }).catchError((err) {
        if (err is MissingPluginException) {
          debugPrint('receive_sharing_intent not available on this platform: $err');
        } else {
          debugPrint('Error getting initial shared data: $err');
        }
      });
    } else {
      debugPrint('receive_sharing_intent disabled on this platform');
    }
  }

  Future<void> _checkApiKeys() async {
    // Check if we have either Gemini or RapidAPI key configured
    // We check individual keys to be more specific, but for now a general check is fine
    // per the SettingsService.hasApiKeys implementation.
    final hasKeys = await SettingsService.hasApiKeys();
    if (!mounted) return;

    // Clear any existing banners to avoid duplicates
    ScaffoldMessenger.of(context).clearMaterialBanners();

    if (!hasKeys) {
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: const Text(
            'API keys are missing. features will not work.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          actions: [
            TextButton(
              onPressed: () async {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                // Re-check keys when returning from settings
                _checkApiKeys();
              },
              child: const Text('CONFIGURE'),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              },
              child: const Text('DISMISS'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _showAddUrlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add from Instagram'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Instagram URL',
                hintText: 'https://www.instagram.com/reel/...',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text(
              'Paste an Instagram reel or post URL to extract the content.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _urlController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final url = _urlController.text.trim();
              if (url.isNotEmpty) {
                Navigator.pop(context);
                _showContentTypeDialog(url);
              }
            },
            child: const Text('Process'),
          ),
        ],
      ),
    );
  }

  void _showContentTypeDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('What type of content is this?'),
        content: const Text('Please select whether this is a recipe or a place.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processUrl(url, isPlace: false);
            },
            child: const Text('Recipe'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _processUrl(url, isPlace: true);
            },
            child: const Text('Place'),
          ),
        ],
      ),
    );
  }

  void _processUrl(String url, {bool isPlace = true}) {
    if (url.isNotEmpty) {
      if (isPlace) {
        Provider.of<PlaceProvider>(context, listen: false).addPlaceFromUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Processing Place...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        Provider.of<RecipeProvider>(context, listen: false).addRecipeFromUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Processing Recipe...'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      _urlController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUrlDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add from Instagram'),
        tooltip: 'Add recipe or place from Instagram',
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.place),
            selectedIcon: Icon(Icons.place),
            label: 'Places',
          ),
        ],
      ),
    );
  }
}
