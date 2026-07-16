package com.example.lifebalance

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.widget.TextView

class MainActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val textView = TextView(this)
        textView.text = "LifeBalance Wear OS\nIniciando sensores..."
        textView.textAlignment = TextView.TEXT_ALIGNMENT_CENTER
        setContentView(textView)

        // Start the background sensor service
        val serviceIntent = Intent(this, SensorService::class.java)
        startForegroundService(serviceIntent)
        
        textView.text = "LifeBalance Wear OS\nMonitoreando en segundo plano."
    }
}
