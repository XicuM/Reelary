
import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

class ProcessingState {
  final String title;
  final String content;
  final bool showProgress;
  final int progress;
  final int maxProgress;

  ProcessingState({
    required this.title,
    required this.content,
    this.showProgress = false,
    this.progress = 0,
    this.maxProgress = 100,
  });
}

class BackgroundProcessingService {
  static final BackgroundProcessingService _instance = BackgroundProcessingService._internal();

  factory BackgroundProcessingService() {
    return _instance;
  }

  BackgroundProcessingService._internal();
  
  static const notificationChannelId = 'processing_channel';
  static const notificationId = 888;

  // Stream for in-app updates (Desktop/Web support)
  final _progressAndStatusController = StreamController<ProcessingState?>.broadcast();
  Stream<ProcessingState?> get progressStream => _progressAndStatusController.stream;

  // Track if service is running locally for Desktop
  bool _isDesktopServiceRunning = false;
  bool get isDesktopServiceRunning => _isDesktopServiceRunning;

  Future<void> initialize() async {
    // Only initialize background service on Android/iOS
    if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();

        /// OPTIONAL, using custom notification channel id
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          notificationChannelId, // id
          'Background Processing', // title
          description: 'Notify about background download and processing', // description
          importance: Importance.low, // importance must be at low or higher level
        );

        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();

        if (Platform.isAndroid) {
          await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
        }
      

        await service.configure(
          androidConfiguration: AndroidConfiguration(
            // this will be executed when app is in foreground or background in separated isolate
            onStart: onStart,

            // auto start service
            autoStart: false,
            isForegroundMode: true,
            
            notificationChannelId: notificationChannelId,
            initialNotificationTitle: 'Reelary Service',
            initialNotificationContent: 'Initializing...',
            foregroundServiceNotificationId: notificationId,
          ),
          iosConfiguration: IosConfiguration(
            // auto start service
            autoStart: false,

            // this will be executed when app is in foreground in separated isolate
            onForeground: onStart,

            // you have to enable background fetch capability on xcode project
            onBackground: onIosBackground,
          ),
        );
    }
  }
  
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
      return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
    
    // Listen for updates from the main isolate to update the notification
    service.on('updateNotification').listen((event) {
      if (event != null) {
          String title = event['title'] ?? 'Processing';
          String content = event['content'] ?? 'Please wait...';
          bool showProgress = event['showProgress'] ?? false;
          int progress = event['progress'] ?? 0;
          int maxProgress = event['maxProgress'] ?? 100;

          flutterLocalNotificationsPlugin.show(
            notificationId,
            title,
            content,
            NotificationDetails(
              android: AndroidNotificationDetails(
                notificationChannelId,
                'Background Processing',
                icon: 'ic_bg_service_small',
                ongoing: true,
                showProgress: showProgress,
                maxProgress: maxProgress,
                progress: progress,
                // Add actions if needed (requires handling intents)
                actions: [
                     // AndroidNotificationAction('cancel_processing', 'Cancel', cancelNotification: false),
                ],
              ),
            ),
          );
      }
    });
  }

  Future<void> startService() async {
    if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();
        if (!await service.isRunning()) {
          await service.startService();
        }
    } else {
       _isDesktopServiceRunning = true;
    }
  }

  Future<void> stopService() async {
    // Send null to clear overlay
    _progressAndStatusController.add(null);

    if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();
        if (await service.isRunning()) {
          service.invoke('stopService');
        }
    } else {
        _isDesktopServiceRunning = false;
    }
  }
  
  void updateNotification({
      required String title, 
      required String content,
      bool showProgress = false,
      int progress = 0,
      int maxProgress = 100,
  }) {
      // 1. Update In-App Stream (For all platforms)
      _progressAndStatusController.add(ProcessingState(
          title: title, 
          content: content, 
          showProgress: showProgress, 
          progress: progress, 
          maxProgress: maxProgress
      ));

      // 2. Update Background Service (Mobile only)
      if (Platform.isAndroid || Platform.isIOS) {
          FlutterBackgroundService().invoke(
              'updateNotification',
              {
                  'title': title,
                  'content': content,
                  'showProgress': showProgress, // Only ints/strings/bools/maps allowed
                  'progress': progress,
                  'maxProgress': maxProgress,
              },
          );
      }
  }
}
