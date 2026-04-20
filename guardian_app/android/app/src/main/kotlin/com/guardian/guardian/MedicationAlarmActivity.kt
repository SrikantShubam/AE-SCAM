package com.guardian.guardian

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MedicationAlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val medicationName =
            intent.getStringExtra(MedicationAlarmReceiver.EXTRA_MEDICATION_NAME).orEmpty()
        val dosage = intent.getStringExtra(MedicationAlarmReceiver.EXTRA_DOSAGE).orEmpty()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val title = TextView(this).apply {
            text = getString(R.string.medication_alarm_title)
            textSize = 28f
            gravity = Gravity.CENTER
        }
        val body = TextView(this).apply {
            text = "$medicationName $dosage is overdue. Please take action now."
            textSize = 20f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 24)
        }
        val dismiss = Button(this).apply {
            text = "I understand"
            setOnClickListener { finish() }
        }

        container.addView(title)
        container.addView(body)
        container.addView(dismiss)
        setContentView(container)
    }
}
