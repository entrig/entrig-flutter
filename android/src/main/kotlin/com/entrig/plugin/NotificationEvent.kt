package com.entrig.plugin

import org.json.JSONObject

data class NotificationEvent(
    val title: String?,
    val body: String?,
    val type: String?,
    val data: Map<String, Any?>?
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "title" to title,
            "body" to body,
            "type" to type,
            "data" to data
        )
    }

    companion object {
        fun fromJson(json: JSONObject): NotificationEvent {
            val title = json.optString("title", "")
            val body = json.optString("body", "")

            val data = mutableMapOf<String, Any>()
            val dataObject = json.optJSONObject("data")
            var type: String? = null
            if (dataObject != null) {
                val keys = dataObject.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    if (key == "type") {
                        type = dataObject.optString(key)
                    } else {
                        data[key] = dataObject.get(key)
                    }
                }
            }

            return NotificationEvent(title, body, type, data)
        }
    }
}
