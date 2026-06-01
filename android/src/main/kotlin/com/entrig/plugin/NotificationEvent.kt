package com.entrig.plugin

data class NotificationEvent(
    val title: String?,
    val body: String?,
    val type: String?,
    val deeplink: String?,
    val data: Map<String, Any?>?
) {
    fun toMap(): Map<String, Any?> {
        return mapOf(
            "title" to title,
            "body" to body,
            "type" to type,
            "deeplink" to deeplink,
            "data" to data
        )
    }

}
