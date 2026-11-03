package deckers.thibault.aves.utils

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import androidx.annotation.RequiresApi
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Best gallery: keeps the reasons the app closed by itself, readable from the app
object CrashLog {
    private const val FILE_NAME = "crash_log.txt"
    private const val MAX_FILE_LENGTH = 256 * 1024L
    private const val MAX_TRACE_LENGTH = 6 * 1024
    private const val MAX_EXIT_REASONS = 12

    @Volatile
    private var installed = false

    private fun file(context: Context) = File(context.filesDir, FILE_NAME)

    private fun now(): String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).format(Date())

    fun install(context: Context) {
        if (installed) return
        installed = true
        val appContext = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                append(appContext, "Crash in thread ${thread.name}", throwable.stackTraceToString())
            } catch (_: Throwable) {
                // never prevent the default crash handling
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    @Synchronized
    fun append(context: Context, title: String, details: String) {
        val file = file(context)
        if (file.exists() && file.length() > MAX_FILE_LENGTH) {
            // keep the most recent half
            val text = file.readText()
            file.writeText(text.substring(text.length / 2))
        }
        file.appendText("=== ${now()} · $title\n$details\n\n")
    }

    fun read(context: Context): String {
        val sb = StringBuilder()
        sb.append("Device: ${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\n\n")
        sb.append(readExitReasons(context))
        val file = file(context)
        sb.append("## Errors\n\n")
        if (file.exists() && file.length() > 0) {
            sb.append(file.readText())
        } else {
            sb.append("(none)\n")
        }
        return sb.toString()
    }

    fun clear(context: Context) {
        file(context).delete()
    }

    private fun readExitReasons(context: Context): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return ""
        return readExitReasonsR(context)
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun readExitReasonsR(context: Context): String {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return ""
        val infos = try {
            am.getHistoricalProcessExitReasons(context.packageName, 0, MAX_EXIT_REASONS)
        } catch (e: Exception) {
            return "## App closings\n\nunavailable: ${e.message}\n\n"
        }
        val format = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT)
        val sb = StringBuilder("## App closings (most recent first)\n\n")
        if (infos.isEmpty()) sb.append("(none)\n")
        infos.forEach { info ->
            sb.append("=== ${format.format(Date(info.timestamp))} · ${reasonName(info.reason)}")
            info.description?.let { sb.append(" · $it") }
            sb.append("\nimportance=${info.importance}, pss=${info.pss / 1024}MB, rss=${info.rss / 1024}MB, status=${info.status}\n")
            if (info.reason == ApplicationExitInfo.REASON_ANR) {
                try {
                    info.traceInputStream?.use { input ->
                        val bytes = ByteArray(MAX_TRACE_LENGTH)
                        val count = input.read(bytes)
                        if (count > 0) sb.append(String(bytes, 0, count)).append("\n")
                    }
                } catch (_: Exception) {
                    // trace unavailable
                }
            }
            sb.append("\n")
        }
        sb.append("\n")
        return sb.toString()
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun reasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_EXIT_SELF -> "closed by the app"
        ApplicationExitInfo.REASON_SIGNALED -> "killed by a signal"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW MEMORY"
        ApplicationExitInfo.REASON_CRASH -> "CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "NATIVE CRASH"
        ApplicationExitInfo.REASON_ANR -> "NOT RESPONDING (ANR)"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "initialization failure"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "permission change"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE RESOURCE USAGE"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "closed by the user"
        ApplicationExitInfo.REASON_USER_STOPPED -> "stopped by the user"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "dependency died"
        ApplicationExitInfo.REASON_OTHER -> "other (system)"
        else -> "reason $reason"
    }
}
