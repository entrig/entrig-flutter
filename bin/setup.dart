#!/usr/bin/env dart

import 'dart:io';
import 'package:xml/xml.dart';

void main(List<String> args) {
  if (args.isEmpty || args.first != 'ios') {
    print('Usage: dart run entrig:setup ios');
    exit(1);
  }

  print('🔧 Entrig iOS Setup\n');

  final appDelegatePath = 'ios/Runner/AppDelegate.swift';
  final file = File(appDelegatePath);

  if (!file.existsSync()) {
    print('❌ Error: $appDelegatePath not found');
    print('   Make sure you run this from your Flutter project root.');
    exit(1);
  }

  print('✅ Found: $appDelegatePath');

  final content = file.readAsStringSync();

  // Check if already setup
  if (content.contains('EntrigPlugin.checkLaunchNotification')) {
    print('✅ Entrig is already configured in AppDelegate.swift');
    print('   No changes needed.\n');
    exit(0);
  }

  print('📝 Analyzing AppDelegate.swift...\n');

  // Parse the file
  final modified = injectEntrigCode(content);

  if (modified == null) {
    print(
      '⚠️  Warning: Existing delegate methods detected in AppDelegate.swift',
    );
    print('   You already have custom notification handling methods.');
    print('\n📝 Please manually add these calls to your existing methods:\n');
    print('   In didFinishLaunchingWithOptions:');
    print('     UNUserNotificationCenter.current().delegate = self');
    print('     EntrigPlugin.checkLaunchNotification(launchOptions)\n');
    print('   In didRegisterForRemoteNotificationsWithDeviceToken:');
    print(
      '     EntrigPlugin.didRegisterForRemoteNotifications(deviceToken: deviceToken)\n',
    );
    print('   In didFailToRegisterForRemoteNotificationsWithError:');
    print(
      '     EntrigPlugin.didFailToRegisterForRemoteNotifications(error: error)\n',
    );
    print('   In userNotificationCenter:willPresent:');
    print('     EntrigPlugin.willPresentNotification(notification)\n');
    print('   In userNotificationCenter:didReceive:');
    print('     EntrigPlugin.didReceiveNotification(response)\n');
    exit(0);
  }

  // Backup original
  final backupPath = 'ios/Runner/AppDelegate.swift.backup';
  file.copySync(backupPath);
  print('💾 Backup created: $backupPath');

  // Write modified content
  file.writeAsStringSync(modified);

  print('✅ Successfully configured AppDelegate.swift\n');
  print('📋 Changes made:');
  print('   • Added import UserNotifications');
  print('   • Added import entrig');
  print('   • Set UNUserNotificationCenter delegate');
  print('   • Added checkLaunchNotification call');
  print('   • Added didRegisterForRemoteNotifications method');
  print('   • Added didFailToRegisterForRemoteNotifications method');
  print('   • Added userNotificationCenter:willPresent method');
  print('   • Added userNotificationCenter:didReceive method\n');

  // Update entitlements and Info.plist
  updateEntitlements();
  updateInfoPlist();

  print('🎉 Setup complete! Run your iOS app to test notifications.\n');
}

String? injectEntrigCode(String content) {
  // Check if it's Swift (not Objective-C)
  if (!content.contains('class AppDelegate') ||
      !content.contains('FlutterAppDelegate')) {
    return null;
  }

  var modified = content;

  // 1. Add imports if not present
  if (!content.contains('import UserNotifications')) {
    final importMatch = RegExp(r'import \w+').firstMatch(modified);
    if (importMatch != null) {
      modified = modified.replaceFirst(
        importMatch.group(0)!,
        '${importMatch.group(0)}\nimport UserNotifications',
      );
    }
  }

  if (!content.contains('import entrig')) {
    final importMatch = RegExp(r'import \w+').firstMatch(modified);
    if (importMatch != null) {
      modified = modified.replaceFirst(
        importMatch.group(0)!,
        '${importMatch.group(0)}\nimport entrig',
      );
    }
  }

  // 2. Find didFinishLaunchingWithOptions method
  final didFinishPattern = RegExp(
    r'override func application\(\s*_\s+application:\s*UIApplication,\s*didFinishLaunchingWithOptions\s+launchOptions:[^\)]*\)\s*->\s*Bool\s*\{',
    multiLine: true,
  );

  final match = didFinishPattern.firstMatch(modified);
  if (match == null) return null;

  final insertPosition = match.end;

  // Find the return statement
  final returnPattern = RegExp(
    r'return super\.application\(application, didFinishLaunchingWithOptions: launchOptions\)',
  );
  final returnMatch = returnPattern.firstMatch(
    modified.substring(insertPosition),
  );

  if (returnMatch == null) return null;

  // Insert Entrig setup before return
  final setupCode = '''

    // Setup Entrig notification handling
    UNUserNotificationCenter.current().delegate = self
    EntrigPlugin.checkLaunchNotification(launchOptions)
''';

  final returnPosition = insertPosition + returnMatch.start;
  modified =
      modified.substring(0, returnPosition) +
      setupCode +
      '\n    ' +
      modified.substring(returnPosition);

  // 3. Check if delegate methods already exist
  if (_hasExistingDelegateMethods(modified)) {
    return null; // Signal that manual integration is needed
  }

  // 4. Add all delegate methods
  final lastBraceIndex = modified.lastIndexOf('}');
  if (lastBraceIndex == -1) return null;

  final methodsToAdd = '''

  override func application(_ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    EntrigPlugin.didRegisterForRemoteNotifications(deviceToken: deviceToken)
  }

  override func application(_ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
    EntrigPlugin.didFailToRegisterForRemoteNotifications(error: error)
  }

  // MARK: - UNUserNotificationCenterDelegate
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    EntrigPlugin.willPresentNotification(notification)
    completionHandler(EntrigPlugin.foregroundPresentationOptions())
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    EntrigPlugin.didReceiveNotification(response)
    completionHandler()
  }
''';

  modified =
      modified.substring(0, lastBraceIndex) +
      methodsToAdd +
      '\n' +
      modified.substring(lastBraceIndex);

  return modified;
}

bool _hasExistingDelegateMethods(String content) {
  // Check if any of the 4 methods already exist
  final patterns = [
    r'func application\([^)]*didRegisterForRemoteNotificationsWithDeviceToken',
    r'func application\([^)]*didFailToRegisterForRemoteNotificationsWithError',
    r'func userNotificationCenter\([^)]*willPresent',
    r'func userNotificationCenter\([^)]*didReceive.*response',
  ];

  for (final pattern in patterns) {
    if (RegExp(pattern, multiLine: true).hasMatch(content)) {
      return true;
    }
  }
  return false;
}

void updateEntitlements() {
  final entitlementsPath = 'ios/Runner/Runner.entitlements';
  final file = File(entitlementsPath);

  if (!file.existsSync()) {
    print('⚠️  Warning: $entitlementsPath not found');
    print('   You need to create this file in Xcode:\n');
    print('   1. Open ios/Runner.xcworkspace in Xcode');
    print('   2. Select Runner target → Signing & Capabilities tab');
    print('   3. Click "+ Capability" → Push Notifications');
    print('   4. This will create Runner.entitlements with aps-environment\n');
    return;
  }

  print('\n📝 Checking Runner.entitlements...');

  try {
    final content = file.readAsStringSync();
    final document = XmlDocument.parse(content);
    final dict = document.findAllElements('dict').first;

    // Check if aps-environment already exists
    bool hasApsEnvironment = false;
    final children = dict.children.whereType<XmlElement>().toList();

    for (var i = 0; i < children.length; i++) {
      if (children[i].name.local == 'key' &&
          children[i].innerText == 'aps-environment') {
        hasApsEnvironment = true;
        break;
      }
    }

    if (hasApsEnvironment) {
      print('✅ aps-environment already configured in Runner.entitlements');
      print('   No changes needed.');
      return;
    }

    // Add aps-environment key
    final keyElement = XmlElement(XmlName('key'), [], [XmlText('aps-environment')]);
    final stringElement = XmlElement(XmlName('string'), [], [XmlText('development')]);

    dict.children.add(XmlText('\n'));
    dict.children.add(keyElement);
    dict.children.add(XmlText('\n'));
    dict.children.add(stringElement);
    dict.children.add(XmlText('\n'));

    // Backup and write
    final backupPath = '$entitlementsPath.backup';
    file.copySync(backupPath);

    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '\t'));

    print('✅ Added aps-environment to Runner.entitlements');
    print('💾 Backup created: $backupPath');
  } catch (e) {
    print('❌ Error updating entitlements: $e');
    print('   Please manually add aps-environment to Runner.entitlements');
  }
}

void updateInfoPlist() {
  final infoPlistPath = 'ios/Runner/Info.plist';
  final file = File(infoPlistPath);

  if (!file.existsSync()) {
    print('⚠️  Warning: $infoPlistPath not found');
    print('   Skipping Info.plist configuration.');
    return;
  }

  print('\n📝 Checking Info.plist...');

  try {
    final content = file.readAsStringSync();
    final document = XmlDocument.parse(content);
    final dict = document.findAllElements('dict').first;

    // Check if UIBackgroundModes already exists
    bool hasBackgroundModes = false;
    final children = dict.children.whereType<XmlElement>().toList();

    for (var i = 0; i < children.length; i++) {
      if (children[i].name.local == 'key' &&
          children[i].innerText == 'UIBackgroundModes') {
        hasBackgroundModes = true;
        break;
      }
    }

    if (hasBackgroundModes) {
      print('✅ UIBackgroundModes already configured in Info.plist');
      print('   No changes needed.');
      return;
    }

    // Add UIBackgroundModes with remote-notification and fetch
    final keyElement = XmlElement(XmlName('key'), [], [XmlText('UIBackgroundModes')]);
    final arrayElement = XmlElement(XmlName('array'));
    final remoteNotificationElement = XmlElement(XmlName('string'), [], [XmlText('remote-notification')]);
    final fetchElement = XmlElement(XmlName('string'), [], [XmlText('fetch')]);

    arrayElement.children.add(XmlText('\n\t'));
    arrayElement.children.add(remoteNotificationElement);
    arrayElement.children.add(XmlText('\n\t'));
    arrayElement.children.add(fetchElement);
    arrayElement.children.add(XmlText('\n'));

    dict.children.add(XmlText('\n'));
    dict.children.add(keyElement);
    dict.children.add(XmlText('\n'));
    dict.children.add(arrayElement);
    dict.children.add(XmlText('\n'));

    // Backup and write
    final backupPath = '$infoPlistPath.backup';
    file.copySync(backupPath);

    file.writeAsStringSync(document.toXmlString(pretty: true, indent: '\t'));

    print('✅ Added UIBackgroundModes to Info.plist');
    print('💾 Backup created: $backupPath');
  } catch (e) {
    print('❌ Error updating Info.plist: $e');
    print('   Please manually add UIBackgroundModes to Info.plist');
  }
}
