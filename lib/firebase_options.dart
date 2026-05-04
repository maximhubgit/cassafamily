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
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions non supportato per $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyB4toju0KCdLvl6RnGc0F6UrytpJ9aGQMs",
    authDomain: "cassafamily.firebaseapp.com",
    projectId: "cassafamily",
    storageBucket: "cassafamily.firebasestorage.app",
    messagingSenderId: "288514978155",
    appId: "1:288514978155:web:9633888fd2789182505c2e",
    measurementId: "G-HL5MKKRM2R"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDRvxaDNEhqwdoGJDzcvBnga1135WAh0Yg",
    appId: "1:288514978155:android:74fce3223e9888a7505c2e",
    messagingSenderId: "288514978155",
    projectId: "cassafamily",
    storageBucket: "cassafamily.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'INSERISCI_API_KEY',
    appId: 'INSERISCI_IOS_APP_ID',
    messagingSenderId: 'INSERISCI_MESSAGING_SENDER_ID',
    projectId: 'INSERISCI_PROJECT_ID',
    storageBucket: 'INSERISCI_PROJECT_ID.appspot.com',
  );
}
