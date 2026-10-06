package com.hazm.hazm_app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel

class GravityStream(context: Context) : EventChannel.StreamHandler, SensorEventListener {
    private val sensors = context.getSystemService(SensorManager::class.java)
    private val sensor = sensors?.getDefaultSensor(Sensor.TYPE_GRAVITY)
        ?: sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val raw = sensor?.type == Sensor.TYPE_ACCELEROMETER
    private val values = FloatArray(3)
    private var sink: EventChannel.EventSink? = null
    private var primed = false
    private var sentAt = 0L

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        primed = false
        sentAt = 0L
        val source = sensor ?: return
        sensors?.registerListener(this, source, SensorManager.SENSOR_DELAY_GAME)
    }

    override fun onCancel(arguments: Any?) = stop()

    fun stop() {
        sensors?.unregisterListener(this)
        sink = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        for (axis in 0..2) {
            values[axis] = if (raw && primed) values[axis] + (event.values[axis] - values[axis]) * SMOOTHING else event.values[axis]
        }
        primed = true
        if (event.timestamp - sentAt < INTERVAL_NS) return
        sentAt = event.timestamp
        sink?.success(doubleArrayOf(values[0].toDouble(), values[1].toDouble(), values[2].toDouble()))
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private companion object {
        const val SMOOTHING = 0.15f
        const val INTERVAL_NS = 80_000_000L
    }
}
