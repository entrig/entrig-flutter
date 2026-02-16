package com.entrig.plugin

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import com.entrig.sdk.Entrig
import com.entrig.sdk.models.EntrigConfig
import com.entrig.sdk.models.NotificationEvent

class EntrigPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var context: Context
    private var activity: Activity? = null
    private var cachedInitialNotification: Map<String, Any?>? = null
    private var initialNotificationConsumed = false

    companion object {
        lateinit var notificationChannel: MethodChannel
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        notificationChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "com.entrig.plugin.notifications")
        notificationChannel.setMethodCallHandler(this)

        // Set up SDK listeners
        Entrig.setOnForegroundNotificationListener { notification ->
            Log.d("ENTRIG SDK FG",notification.toMap().toString())
            notificationChannel.invokeMethod(
                "notifications#onForeground",
                notification.toMap()
            )
        }

        Entrig.setOnNotificationOpenedListener { notification ->
            Log.d("ENTRIG SDK BG",notification.toMap().toString())
            notificationChannel.invokeMethod(
                "notifications#onClick",
                notification.toMap()
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "init" -> {
                val args = call.arguments as Map<*, *>
                val apiKey = args["apiKey"].toString()

                if (apiKey.isEmpty()) {
                    result.error("INVALID_API_KEY", "API key cannot be empty", null)
                    return
                }

                val handlePermission = args["handlePermission"] as? Boolean ?: true
                val showForegroundNotification = args["showForegroundNotification"] as? Boolean ?: true
                val config = EntrigConfig(
                    apiKey = apiKey,
                    handlePermission = handlePermission,
                    showForegroundNotification = showForegroundNotification
                )

                Entrig.initialize(context, config) { success, error ->
                    if (success) {
                        result.success(null)
                    } else {
                        result.error("INIT_FAILED", error ?: "Initialization failed", null)
                    }
                }
            }

            "getInitialNotification" -> {
                if (!initialNotificationConsumed && cachedInitialNotification != null) {
                    result.success(cachedInitialNotification)
                    initialNotificationConsumed = true
                    cachedInitialNotification = null
                } else {
                    // Check SDK for initial notification
                    val initialNotification = Entrig.getInitialNotification()
                    result.success(initialNotification?.toMap())
                }
            }

            "register" -> {
                val args = call.arguments as Map<*, *>
                val userId = args["userId"].toString()

                activity?.let { act ->
                    Entrig.register(userId, act, "flutter") { success, error ->
                        if (success) {
                            result.success(null)
                        } else {
                            result.error("REGISTER_FAILED", error ?: "Registration failed", null)
                        }
                    }
                } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            }

            "requestPermission" -> {
                activity?.let { act ->
                    Entrig.requestPermission(act) { granted ->
                        result.success(granted)
                    }
                } ?: result.error("NO_ACTIVITY", "Activity not available", null)
            }

            "unregister" -> {
                Entrig.unregister { success, error ->
                    if (success) {
                        result.success(null)
                    } else {
                        result.error("UNREGISTER_FAILED", error ?: "Unregistration failed", null)
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        // Forward to SDK
        Entrig.onRequestPermissionsResult(requestCode, grantResults)
        return true
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        notificationChannel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)

        // Set activity on SDK for foreground detection (lifecycle callbacks
        // registered in initialize() won't fire for already-resumed activities)
        Entrig.setActivity(binding.activity)

        // Check for initial intent (app launched from notification in terminated state)
        activity?.intent?.let { intent ->
            if (intent.extras != null && intent.extras!!.keySet().isNotEmpty() &&
                (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0
            ) {
                Log.d("EntrigPlugin", "Initial intent has extras, caching notification")
                // Let SDK handle it
                Entrig.handleIntent(intent)

                // Also cache for Flutter's getInitialNotification
                cachedInitialNotification = extractNotificationData(intent)
            }
        }

        // When app is in background not terminated
        binding.addOnNewIntentListener { intent ->
            Log.d("EntrigPlugin", "New intent received: $intent")
            Entrig.handleIntent(intent)
            false
        }
    }

    private fun extractNotificationData(intent: Intent?): Map<String, Any?>? {
        val extras = intent?.extras ?: return null

        // Check if this is a FCM notification by looking for message ID
        val messageId = extras.getString("google.message_id") ?: extras.getString("message_id")
        if (messageId == null) {
            Log.d("EntrigPlugin", "Not a FCM notification intent, skipping")
            return null
        }

        // Extract and decode the payload JSON string
        val payloadString = extras.getString("payload")
        val payload = payloadString?.let { jsonDecode(it) }?.toMutableMap() ?: mutableMapOf()

        // Extract title, body, and type from data
        val title = payload.remove("title")?.toString() ?: ""
        val body = payload.remove("body")?.toString() ?: ""
        val type = payload.remove("type")?.toString()

        val notificationEvent = NotificationEvent(
            title = title,
            body = body,
            type = type,
            data = payload
        )

        return notificationEvent.toMap()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        Entrig.setActivity(binding.activity)

        // Re-add onNewIntent listener after config change
        binding.addOnNewIntentListener { intent ->
            Log.d("EntrigPlugin", "New intent received: $intent")
            Entrig.handleIntent(intent)
            false
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
        Entrig.setActivity(null)
    }
}
