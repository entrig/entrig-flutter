## 0.0.1-beta

* Initial version

## 0.0.2-beta

* Enhanced iOS setup command to automatically update Info.plist and Runner.entitlements
* Added auto-register device with Supabase Auth integration
* Added notification type support for categorizing notifications

## 0.0.5-dev

* Updated to identify debug device tokens when register for Testing from dashboard

## 0.0.6-dev

* **BREAKING**: Removed `AutoRegisterWithSupabaseAuth` to eliminate Supabase dependency
* Users should now implement auth listeners manually (see README for example)
* Package is now lighter and avoids version conflicts with Supabase dependencies

## 0.0.7-dev
* Added `showForegroundNotification` option to control whether notifications are displayed when app is in foreground

## 0.0.8-dev
* Fixed iOS foreground notification display not respecting `showForegroundNotification` setting
