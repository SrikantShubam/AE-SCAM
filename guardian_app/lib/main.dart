import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/services/local_db.dart';
import 'features/protection/services/emergency_disable_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrapApp();
  FirebaseMessaging.onBackgroundMessage(_guardianFirebaseBackgroundHandler);

  runApp(const ProviderScope(child: GuardianApp()));
}

@pragma('vm:entry-point')
Future<void> _guardianFirebaseBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  await EmergencyDisableSyncService.applyFcmDataPayload(message.data);
}

Future<void> _bootstrapApp() async {
  try {
    await dotenv.load(fileName: '.env.example');
  } catch (_) {
    // Keep the app bootable until a real local env file is supplied.
  }

  try {
    await Firebase.initializeApp();
    await _configureCrashlytics();
  } on FirebaseException catch (_) {
    // Keep the prototype bootable when Firebase config is not present yet.
  } catch (_) {
    // Keep the prototype bootable when Firebase initialization fails for other reasons.
  }

  await LocalDb.instance.database;
}

Future<void> _configureCrashlytics() async {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
}
