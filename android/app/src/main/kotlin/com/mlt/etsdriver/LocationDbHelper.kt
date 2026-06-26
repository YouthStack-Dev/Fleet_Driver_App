package com.mlt.etsdriver

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class LocationDbHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "mlt_offline_location.db"
        const val DATABASE_VERSION = 1
        const val TABLE_NAME = "location_queue"
        const val COL_ID = "id"
        const val COL_ROUTE_ID = "route_id"
        const val COL_LATITUDE = "latitude"
        const val COL_LONGITUDE = "longitude"
        const val COL_SPEED = "speed"
        const val COL_TIMESTAMP = "timestamp"
    }

    override fun onCreate(db: SQLiteDatabase) {
        val createTable = ("CREATE TABLE $TABLE_NAME (" +
                "$COL_ID INTEGER PRIMARY KEY AUTOINCREMENT, " +
                "$COL_ROUTE_ID TEXT, " +
                "$COL_LATITUDE REAL, " +
                "$COL_LONGITUDE REAL, " +
                "$COL_SPEED REAL, " +
                "$COL_TIMESTAMP INTEGER)")
        db.execSQL(createTable)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_NAME")
        onCreate(db)
    }

    fun enqueueLocation(routeId: String, lat: Double, lng: Double, speed: Double?) {
        try {
            val db = this.writableDatabase
            val values = ContentValues().apply {
                put(COL_ROUTE_ID, routeId)
                put(COL_LATITUDE, lat)
                put(COL_LONGITUDE, lng)
                if (speed != null) {
                    put(COL_SPEED, speed)
                } else {
                    putNull(COL_SPEED)
                }
                put(COL_TIMESTAMP, System.currentTimeMillis())
            }
            db.insert(TABLE_NAME, null, values)
        } catch (e: Exception) {
            android.util.Log.e("MLT_DbHelper", "Error enqueuing location: ${e.message}")
        }
    }

    fun getOldestLocation(): QueuedLocation? {
        var location: QueuedLocation? = null
        try {
            val db = this.readableDatabase
            val cursor = db.query(
                TABLE_NAME,
                null,
                null, null, null, null,
                "$COL_TIMESTAMP ASC",
                "1"
            )

            if (cursor.moveToFirst()) {
                val id = cursor.getLong(cursor.getColumnIndexOrThrow(COL_ID))
                val routeId = cursor.getString(cursor.getColumnIndexOrThrow(COL_ROUTE_ID))
                val lat = cursor.getDouble(cursor.getColumnIndexOrThrow(COL_LATITUDE))
                val lng = cursor.getDouble(cursor.getColumnIndexOrThrow(COL_LONGITUDE))
                val speed = if (cursor.isNull(cursor.getColumnIndexOrThrow(COL_SPEED))) {
                    null
                } else {
                    cursor.getDouble(cursor.getColumnIndexOrThrow(COL_SPEED))
                }
                val timestamp = cursor.getLong(cursor.getColumnIndexOrThrow(COL_TIMESTAMP))
                location = QueuedLocation(id, routeId, lat, lng, speed, timestamp)
            }
            cursor.close()
        } catch (e: Exception) {
            android.util.Log.e("MLT_DbHelper", "Error getting oldest location: ${e.message}")
        }
        return location
    }

    fun deleteLocation(id: Long) {
        try {
            val db = this.writableDatabase
            db.delete(TABLE_NAME, "$COL_ID = ?", arrayOf(id.toString()))
        } catch (e: Exception) {
            android.util.Log.e("MLT_DbHelper", "Error deleting location $id: ${e.message}")
        }
    }

    fun getQueueSize(): Int {
        var count = 0
        try {
            val db = this.readableDatabase
            val cursor = db.rawQuery("SELECT COUNT(*) FROM $TABLE_NAME", null)
            if (cursor.moveToFirst()) {
                count = cursor.getInt(0)
            }
            cursor.close()
        } catch (e: Exception) {
            android.util.Log.e("MLT_DbHelper", "Error getting queue size: ${e.message}")
        }
        return count
    }
}

data class QueuedLocation(
    val id: Long,
    val routeId: String,
    val latitude: Double,
    val longitude: Double,
    val speed: Double?,
    val timestamp: Long
)
