import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGaIj5MaPZn-P_SNdmW89q6kh8WSZb40c',
    appId: '1:975202518106:web:8adc73842fdd038b030463',
    messagingSenderId: '975202518106',
    projectId: 'beach-tennis-216f4',
    authDomain: 'beach-tennis-216f4.firebaseapp.com',
    storageBucket: 'beach-tennis-216f4.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA9QlsaelF4QrnfQlZkHJGSa7RWZQNEUT0',
    appId: '1:975202518106:android:67c866c34dc4ede5030463',
    messagingSenderId: '975202518106',
    projectId: 'beach-tennis-216f4',
    storageBucket: 'beach-tennis-216f4.firebasestorage.app',
  );
}
