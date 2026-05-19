package com.guardian.guardian

import android.app.Activity
import android.app.AlertDialog
import android.os.Bundle
import android.database.sqlite.SQLiteDatabase
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

class MedicationAlarmActivity : Activity() {
    private val localDbName = "guardian_local.db"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val medicationName =
            intent.getStringExtra(MedicationAlarmReceiver.EXTRA_MEDICATION_NAME).orEmpty()
        val dosage = intent.getStringExtra(MedicationAlarmReceiver.EXTRA_DOSAGE).orEmpty()
        val note = intent.getStringExtra(MedicationAlarmReceiver.EXTRA_NOTE).orEmpty()

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
        val medication = TextView(this).apply {
            text = medicationName
            textSize = 32f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 8)
        }
        val dosageView = TextView(this).apply {
            text = dosage
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }
        val body = TextView(this).apply {
            text = if (note.isBlank()) {
                "Please confirm this dose now."
            } else {
                note
            }
            textSize = 18f
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 24)
        }
        val tookIt = Button(this).apply {
            text = "I took it"
            textSize = 22f
            minimumHeight = 140
            setOnClickListener {
                acknowledge(status = "taken", skipReason = null)
            }
        }
        val skip = Button(this).apply {
            text = "Skip this one"
            textSize = 22f
            minimumHeight = 140
            setOnClickListener {
                showSkipReasonDialog()
            }
        }

        container.addView(title)
        container.addView(medication)
        container.addView(dosageView)
        container.addView(body)
        container.addView(tookIt)
        container.addView(skip)
        setContentView(container)
    }

    private fun showSkipReasonDialog() {
        val reasons = arrayOf(
            "Not hungry yet",
            "Out of supply",
            "Already took",
            "Other",
        )
        AlertDialog.Builder(this)
            .setTitle("Why are you skipping? (optional)")
            .setItems(reasons) { _, which ->
                val selected = reasons[which]
                if (selected == "Other") {
                    val input = EditText(this)
                    AlertDialog.Builder(this)
                        .setTitle("Add reason (optional)")
                        .setView(input)
                        .setPositiveButton("Save") { _, _ ->
                            val custom = input.text?.toString()?.trim().orEmpty()
                            acknowledge(
                                status = "skipped",
                                skipReason = if (custom.isBlank()) null else custom,
                            )
                        }
                        .setNegativeButton("Skip without reason") { _, _ ->
                            acknowledge(status = "skipped", skipReason = null)
                        }
                        .show()
                } else {
                    acknowledge(status = "skipped", skipReason = selected)
                }
            }
            .setNegativeButton("Skip without reason") { _, _ ->
                acknowledge(status = "skipped", skipReason = null)
            }
            .show()
    }

    private fun acknowledge(status: String, skipReason: String?) {
        val eventId = intent.getStringExtra(MedicationAlarmReceiver.EXTRA_OCCURRENCE_ID).orEmpty()
        if (eventId.isBlank()) {
            finish()
            return
        }
        val dbPath = getDatabasePath(localDbName)
        if (!dbPath.exists()) {
            finish()
            return
        }
        val now = System.currentTimeMillis()
        val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READWRITE)
        db.use { database ->
            database.execSQL(
                """
                UPDATE medication_dose_events
                SET status = ?, skip_reason = ?, acted_at = ?, updated_at = ?
                WHERE id = ?
                """.trimIndent(),
                arrayOf(
                    status,
                    if (status == "skipped") skipReason else null,
                    now,
                    now,
                    eventId,
                ),
            )
        }
        Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show()
        finish()
    }
}
