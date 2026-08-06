package com.example.lifebalance

/**
 * Singleton object to share sensor state between SensorService and MainActivity.
 * This prevents MainActivity from registering its own sensor listeners,
 * which was causing conflicts with the background SensorService.
 */
object WearSensorState {
    @Volatile var variance: Double = 0.0
    @Volatile var idleWindows: Long = 0L
    @Volatile var activeWindows: Long = 0L
    @Volatile var alertWindows: Long = 90L
    @Volatile var alertShown: Boolean = false
    @Volatile var steps: Int = 0
    @Volatile var heartRate: Float = 0f
    @Volatile var isOnBody: Boolean = true
    @Volatile var gyroX: Float = 0f
    @Volatile var gyroY: Float = 0f
    @Volatile var gyroZ: Float = 0f
    @Volatile var resetRequested: Boolean = false
}
