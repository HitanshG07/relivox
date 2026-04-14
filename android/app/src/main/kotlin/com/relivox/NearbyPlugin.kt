package com.relivox

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * NearbyPlugin – bridges Google Nearby Connections (P2P_CLUSTER strategy)
 * to Dart via a MethodChannel.
 *
 * Channel: "com.relivox/nearby"
 *
 * Outbound calls (Dart → Kotlin):
 *   startAdvertising(userName:String)
 *   startDiscovery()
 *   stopAll()
 *   requestConnection(endpointId:String)
 *   acceptConnection(endpointId:String)
 *   rejectConnection(endpointId:String)
 *   sendPayload(endpointId:String, payload:String)
 *   broadcastPayload(payload:String)          ← sends to all connected peers
 *   disconnectFromEndpoint(endpointId:String)
 *
 * Inbound callbacks (Kotlin → Dart):
 *   onEndpointFound(endpointId, endpointName)
 *   onEndpointLost(endpointId)
 *   onConnectionInitiated(endpointId, endpointName, token)
 *   onConnectionResult(endpointId, statusCode)
 *   onDisconnected(endpointId)
 *   onPayloadReceived(endpointId, payload)
 */
class NearbyPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    // Track all currently connected endpoint IDs for broadcast
    private val connectedEndpoints = mutableSetOf<String>()

    private val SERVICE_ID = "com.relivox.nearby.v1"
    private val STRATEGY = Strategy.P2P_CLUSTER

    // ── FlutterPlugin lifecycle ──────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.relivox/nearby")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        safeStopAll()
    }

    // ── MethodCallHandler ────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            "startAdvertising" -> {
                val userName = call.argument<String>("userName") ?: "Relivox"
                startAdvertising(userName, result)
            }

            "startDiscovery" -> startDiscovery(result)
            "stopAdvertising" -> {
                Nearby.getConnectionsClient(context).stopAdvertising()
                result.success(null)
            }
            "stopDiscovery" -> {
                Nearby.getConnectionsClient(context).stopDiscovery()
                result.success(null)
            }

            "stopAll" -> {
                safeStopAll()
                result.success(null)
            }

            "requestConnection" -> {
                val eid = call.argument<String>("endpointId") ?: return result.illegalArg("endpointId")
                val userName = call.argument<String>("userName") ?: "Relivox"
                requestConnection(eid, userName, result)
            }

            "acceptConnection" -> {
                val eid = call.argument<String>("endpointId") ?: return result.illegalArg("endpointId")
                acceptConnection(eid, result)
            }

            "rejectConnection" -> {
                val eid = call.argument<String>("endpointId") ?: return result.illegalArg("endpointId")
                Nearby.getConnectionsClient(context).rejectConnection(eid)
                result.success(null)
            }

            "sendPayload" -> {
                val eid = call.argument<String>("endpointId") ?: return result.illegalArg("endpointId")
                val payload = call.argument<String>("payload") ?: return result.illegalArg("payload")
                sendToEndpoint(eid, payload)
                result.success(null)
            }

            "broadcastPayload" -> {
                val payload = call.argument<String>("payload") ?: return result.illegalArg("payload")
                broadcastToAll(payload)
                result.success(null)
            }

            "disconnectFromEndpoint" -> {
                val eid = call.argument<String>("endpointId") ?: return result.illegalArg("endpointId")
                Nearby.getConnectionsClient(context).disconnectFromEndpoint(eid)
                connectedEndpoints.remove(eid)
                result.success(null)
            }

            "getConnectedEndpoints" -> {
                result.success(connectedEndpoints.toList())
            }

            else -> result.notImplemented()
        }
    }

    // ── Advertising ──────────────────────────────────────────────────────────

    private fun startAdvertising(userName: String, result: Result) {
        val opts = AdvertisingOptions.Builder().setStrategy(STRATEGY).build()
        Nearby.getConnectionsClient(context)
            .startAdvertising(userName, SERVICE_ID, connectionLifecycleCallback, opts)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { e ->
                result.error("ADVERTISING_FAILED", e.message, null)
            }
    }

    // ── Discovery ────────────────────────────────────────────────────────────

    private fun startDiscovery(result: Result) {
        val opts = DiscoveryOptions.Builder().setStrategy(STRATEGY).build()
        Nearby.getConnectionsClient(context)
            .startDiscovery(SERVICE_ID, endpointDiscoveryCallback, opts)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { e ->
                result.error("DISCOVERY_FAILED", e.message, null)
            }
    }

    // ── Connection ───────────────────────────────────────────────────────────

    private fun requestConnection(eid: String, userName: String, result: Result) {
        Nearby.getConnectionsClient(context)
            .requestConnection(userName, eid, connectionLifecycleCallback)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { e ->
                result.error("REQUEST_FAILED", e.message, null)
            }
    }

    private fun acceptConnection(eid: String, result: Result) {
        Nearby.getConnectionsClient(context)
            .acceptConnection(eid, payloadCallback)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { e ->
                result.error("ACCEPT_FAILED", e.message, null)
            }
    }

    // ── Payload ──────────────────────────────────────────────────────────────

    private fun sendToEndpoint(eid: String, payload: String) {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        Nearby.getConnectionsClient(context)
            .sendPayload(eid, Payload.fromBytes(bytes))
    }

    private fun broadcastToAll(payload: String) {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val p = Payload.fromBytes(bytes)
        for (eid in connectedEndpoints.toList()) {
            Nearby.getConnectionsClient(context).sendPayload(eid, p)
        }
    }

    // ── Stop ─────────────────────────────────────────────────────────────────

    private fun safeStopAll() {
        try {
            Nearby.getConnectionsClient(context).stopAllEndpoints()
            Nearby.getConnectionsClient(context).stopAdvertising()
            Nearby.getConnectionsClient(context).stopDiscovery()
        } catch (_: Exception) { /* ignore on shutdown */ }
        connectedEndpoints.clear()
    }

    // ── ConnectionLifecycleCallback ──────────────────────────────────────────

    private val connectionLifecycleCallback = object : ConnectionLifecycleCallback() {
        override fun onConnectionInitiated(eid: String, info: ConnectionInfo) {
            invokeOnMain("onConnectionInitiated", mapOf(
                "endpointId"   to eid,
                "endpointName" to info.endpointName,
                "token"        to info.authenticationToken
            ))
        }

        override fun onConnectionResult(eid: String, resolution: ConnectionResolution) {
            val code = resolution.status.statusCode
            if (code == ConnectionsStatusCodes.STATUS_OK) {
                connectedEndpoints.add(eid)
            }
            invokeOnMain("onConnectionResult", mapOf(
                "endpointId" to eid,
                "statusCode" to code
            ))
        }

        override fun onDisconnected(eid: String) {
            connectedEndpoints.remove(eid)
            invokeOnMain("onDisconnected", mapOf("endpointId" to eid))
        }
    }

    // ── EndpointDiscoveryCallback ────────────────────────────────────────────

    private val endpointDiscoveryCallback = object : EndpointDiscoveryCallback() {
        override fun onEndpointFound(eid: String, info: DiscoveredEndpointInfo) {
            invokeOnMain("onEndpointFound", mapOf(
                "endpointId"   to eid,
                "endpointName" to info.endpointName
            ))
        }

        override fun onEndpointLost(eid: String) {
            invokeOnMain("onEndpointLost", mapOf("endpointId" to eid))
        }
    }

    // ── PayloadCallback ──────────────────────────────────────────────────────

    private val payloadCallback = object : PayloadCallback() {
        override fun onPayloadReceived(eid: String, payload: Payload) {
            if (payload.type == Payload.Type.BYTES) {
                val text = String(payload.asBytes()!!, Charsets.UTF_8)
                invokeOnMain("onPayloadReceived", mapOf(
                    "endpointId" to eid,
                    "payload"    to text
                ))
            }
        }

        override fun onPayloadTransferUpdate(eid: String, update: PayloadTransferUpdate) {
            // No-op for bytes payload – transfer is atomic
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun invokeOnMain(method: String, args: Any?) {
        mainHandler.post { channel.invokeMethod(method, args) }
    }

    private fun Result.illegalArg(arg: String) =
        error("ILLEGAL_ARGUMENT", "Missing required argument: $arg", null)
}
