import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const bool isConfigured = true;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError('Firebase is not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAmgEe7HO4YgMqdUOTI-EI7wLv-_nfPhqc',
    appId: '1:548101662038:web:ef2c3879e9360c1054e2f7',
    messagingSenderId: '548101662038',
    projectId: 'progressive-overload-58294',
    authDomain: 'progressive-overload-58294.firebaseapp.com',
    storageBucket: 'progressive-overload-58294.firebasestorage.app',
    measurementId: 'G-YFXZ8XBYEG',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAokCVg1Hw0oRK7x3M0m6UUUTvk5fhbkx4',
    appId: '1:548101662038:android:a608e0cfd371599454e2f7',
    messagingSenderId: '548101662038',
    projectId: 'progressive-overload-58294',
    storageBucket: 'progressive-overload-58294.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyApQlaexZ-Slr0qHi2lqsBIeFRuCAuHtxo',
    appId: '1:548101662038:ios:922a7baae29f15c254e2f7',
    messagingSenderId: '548101662038',
    projectId: 'progressive-overload-58294',
    storageBucket: 'progressive-overload-58294.firebasestorage.app',
    iosBundleId: 'com.mahamad.fitness.progressiveOverload',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyApQlaexZ-Slr0qHi2lqsBIeFRuCAuHtxo',
    appId: '1:548101662038:ios:922a7baae29f15c254e2f7',
    messagingSenderId: '548101662038',
    projectId: 'progressive-overload-58294',
    storageBucket: 'progressive-overload-58294.firebasestorage.app',
    iosBundleId: 'com.mahamad.fitness.progressiveOverload',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAmgEe7HO4YgMqdUOTI-EI7wLv-_nfPhqc',
    appId: '1:548101662038:web:6a80b9b9f3c731a654e2f7',
    messagingSenderId: '548101662038',
    projectId: 'progressive-overload-58294',
    authDomain: 'progressive-overload-58294.firebaseapp.com',
    storageBucket: 'progressive-overload-58294.firebasestorage.app',
    measurementId: 'G-J4DNWPD72D',
  );
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'REPLACE_WITH_FIREBASE_API_KEY',
    appId: 'REPLACE_WITH_FIREBASE_APP_ID',
    messagingSenderId: 'REPLACE_WITH_FIREBASE_SENDER_ID',
    projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
    storageBucket: 'REPLACE_WITH_FIREBASE_STORAGE_BUCKET',
  );
}
