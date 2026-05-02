package com.example.spend_sense

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.telephony.SmsMessage
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.spendfluxa/sms"
    private val EVENT_CHANNEL = "com.spendfluxa/sms_stream"
    private var smsReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Method channel for reading SMS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readSms" -> {
                    if (checkSmsPermission()) {
                        val limit = call.argument<Int>("limit") ?: 100
                        val since = call.argument<Long>("since")
                        val messages = readSmsMessages(limit, since)
                        result.success(messages)
                    } else {
                        result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Event channel for real-time SMS
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerSmsReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterSmsReceiver()
                }
            }
        )
    }

    private fun checkSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_SMS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true
        }
    }

    private fun readSmsMessages(limit: Int, since: Long?): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()
        
        try {
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("_id", "address", "body", "date")
            
            var selection: String? = null
            var selectionArgs: Array<String>? = null
            
            if (since != null) {
                selection = "date >= ?"
                selectionArgs = arrayOf(since.toString())
            }
            
            val cursor: Cursor? = contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                "date DESC"
            )

            cursor?.use {
                val idIndex = it.getColumnIndex("_id")
                val addressIndex = it.getColumnIndex("address")
                val bodyIndex = it.getColumnIndex("body")
                val dateIndex = it.getColumnIndex("date")
                
                var count = 0
                while (it.moveToNext() && count < limit) {
                    val id = if (idIndex >= 0) it.getString(idIndex) else ""
                    val address = if (addressIndex >= 0) it.getString(addressIndex) else ""
                    val body = if (bodyIndex >= 0) it.getString(bodyIndex) else ""
                    val date = if (dateIndex >= 0) it.getLong(dateIndex) else 0L
                    
                    // Filter for potential bank/transaction SMS
                    if (isPotentialTransactionSms(address, body)) {
                        messages.add(
                            mapOf(
                                "id" to id,
                                "sender" to address,
                                "body" to body,
                                "timestamp" to date
                            )
                        )
                        count++
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return messages
    }

    private fun isPotentialTransactionSms(sender: String, body: String): Boolean {
        // Filter for bank/payment/credit-card SMS
        val transactionKeywords = listOf(
            // Debit account keywords
            "debited", "credited", "paid", "received", "transaction",
            "account", "a/c", "balance", "Rs", "INR", "UPI",
            // Credit card keywords
            "credit card", "credit card", "card ending", "card no",
            "used at", "charged", "spent at",
            // Bank names (debit + credit card senders)
            "HDFC", "ICICI", "SBI", "AXIS", "KOTAK", "YES",
            "INDUS", "IDBI", "PNB", "CANARA", "AMEX", "CITI",
            "HSBC", "RBL", "STANC", "BOB",
            // Payment apps
            "PAYTM", "PHONEPE", "GPAY", "AMAZON", "FLIPKART"
        )

        val bodyLower = body.lowercase()
        val senderUpper = sender.uppercase()

        // Also match on sender containing known CC sender codes
        val ccSenderCodes = listOf("CC", "CARD", "SBICARD", "HDFCCC", "ICICIC", "AXISCC", "KOTAKCC", "INDUSCC")
        if (ccSenderCodes.any { senderUpper.contains(it) }) return true

        return transactionKeywords.any { bodyLower.contains(it.lowercase()) }
    }

    private fun registerSmsReceiver() {
        if (smsReceiver != null) return
        
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
                    val bundle = intent.extras
                    if (bundle != null) {
                        val pdus = bundle.get("pdus") as Array<*>?
                        pdus?.forEach { pdu ->
                            val smsMessage = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                SmsMessage.createFromPdu(pdu as ByteArray, bundle.getString("format"))
                            } else {
                                @Suppress("DEPRECATION")
                                SmsMessage.createFromPdu(pdu as ByteArray)
                            }
                            
                            val sender = smsMessage.displayOriginatingAddress
                            val body = smsMessage.messageBody
                            val timestamp = smsMessage.timestampMillis
                            
                            if (isPotentialTransactionSms(sender, body)) {
                                eventSink?.success(
                                    mapOf(
                                        "id" to timestamp.toString(),
                                        "sender" to sender,
                                        "body" to body,
                                        "timestamp" to timestamp
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
        
        val intentFilter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
        // System broadcasts are exempt from the exported/not-exported requirement.
        // Using no flag works on all API levels and allows the system to deliver SMS.
        registerReceiver(smsReceiver, intentFilter)
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                e.printStackTrace()
            }
            smsReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterSmsReceiver()
        super.onDestroy()
    }
}

