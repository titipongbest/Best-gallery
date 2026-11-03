package deckers.thibault.aves.channel.calls

import android.content.Context
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.utils.CrashLog
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class CrashLogHandler(private val context: Context) : MethodCallHandler {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "read" -> ioScope.launch { safe(call, result, ::read) }
            "append" -> ioScope.launch { safe(call, result, ::append) }
            "clear" -> ioScope.launch { safe(call, result, ::clear) }
            else -> result.notImplemented()
        }
    }

    private fun read(@Suppress("unused_parameter") call: MethodCall, result: MethodChannel.Result) {
        result.success(CrashLog.read(context))
    }

    private fun append(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title") ?: "Error"
        val details = call.argument<String>("details") ?: ""
        CrashLog.append(context, title, details)
        result.success(null)
    }

    private fun clear(@Suppress("unused_parameter") call: MethodCall, result: MethodChannel.Result) {
        CrashLog.clear(context)
        result.success(null)
    }

    companion object {
        const val CHANNEL = "deckers.thibault/aves/crash_log"
    }
}
