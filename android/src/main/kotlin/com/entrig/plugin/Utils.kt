package com.entrig.plugin

import org.json.JSONObject

fun jsonDecode(value: String): MutableMap<String, Any?> {
    val jsonObject = JSONObject(value)
    return jsonObjectToMap(jsonObject)
}

private fun jsonObjectToMap(jsonObject: JSONObject): MutableMap<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    jsonObject.keys().forEach { key ->
        map[key] = jsonToNative(jsonObject.get(key))
    }
    return map
}

private fun jsonToNative(value: Any?): Any? {
    return when (value) {
        is JSONObject -> jsonObjectToMap(value)
        is org.json.JSONArray -> {
            val list = mutableListOf<Any?>()
            for (i in 0 until value.length()) {
                list.add(jsonToNative(value.get(i)))
            }
            list
        }
        org.json.JSONObject.NULL -> null
        else -> value
    }
}
