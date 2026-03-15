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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7feXAnLdt31hENr-zFHkAvsbsS3Be5AQ',
    appId: '1:886170592874:android:329c7b16fd22f02c248c13',
    messagingSenderId: '886170592874',
    projectId: 'sexual-harrasment-management',
    storageBucket: 'sexual-harrasment-management.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB7feXAnLdt31hENr-zFHkAvsbsS3Be5AQ',
    appId: '1:886170592874:ios:YOUR_IOS_APP_ID', // Update this if you have iOS app
    messagingSenderId: '886170592874',
    projectId: 'sexual-harrasment-management',
    storageBucket: 'sexual-harrasment-management.firebasestorage.app',
    iosBundleId: 'com.must.reportHarassment',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7feXAnLdt31hENr-zFHkAvsbsS3Be5AQ',
    appId: '1:886170592874:web:YOUR_WEB_APP_ID', // Update this if you have web app
    messagingSenderId: '886170592874',
    projectId: 'sexual-harrasment-management',
    storageBucket: 'sexual-harrasment-management.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB7feXAnLdt31hENr-zFHkAvsbsS3Be5AQ',
    appId: '1:886170592874:ios:YOUR_IOS_APP_ID', // Same as iOS
    messagingSenderId: '886170592874',
    projectId: 'sexual-harrasment-management',
    storageBucket: 'sexual-harrasment-management.firebasestorage.app',
    iosBundleId: 'com.must.reportHarassment',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB7feXAnLdt31hENr-zFHkAvsbsS3Be5AQ',
    appId: '1:886170592874:web:YOUR_WEB_APP_ID', // Update if you have Windows app
    messagingSenderId: '886170592874',
    projectId: 'sexual-harrasment-management',
    storageBucket: 'sexual-harrasment-management.firebasestorage.app',
  );
}
