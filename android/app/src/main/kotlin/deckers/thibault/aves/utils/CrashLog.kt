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
    private const val MAX_MAIN_STACK_LINES = 80
    private const val MAX_OTHER_THREADS = 8
    private const val MAX_OTHER_STACK_LINES = 25

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
                        sb.append(extractAnrTrace(input.bufferedReader().readText())).append("\n")
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

    // keeps the stack of the main thread, which tells what blocked the app,
    // and the beginning of the other app threads
    private fun extractAnrTrace(trace: String): String {
        val lines = trace.lines()
        val sb = StringBuilder()
        val mainStart = lines.indexOfFirst { it.startsWith("\"main\"") }
        if (mainStart >= 0) {
            sb.append("--- main thread ---\n")
            lines.drop(mainStart).takeWhile { it.isNotBlank() }.take(MAX_MAIN_STACK_LINES).forEach { sb.append(it).append("\n") }
        } else {
            sb.append(trace.take(MAX_TRACE_LENGTH)).append("\n")
        }
        // app threads that are blocked or running our code
        val threadStarts = lines.indices.filter { lines[it].startsWith("\"") && it != mainStart }
        var others = 0
        for (start in threadStarts) {
            if (others >= MAX_OTHER_THREADS) break
            val block = lines.drop(start).takeWhile { it.isNotBlank() }
            val relevant = block.any { it.contains("deckers.thibault") } || block.firstOrNull()?.contains("Blocked") == true
            if (!relevant) continue
            others++
            sb.append("--- ${block.first()} ---\n")
            block.drop(1).filter { it.trimStart().startsWith("at ") || it.contains("waiting") || it.contains("locked") || it.contains("state=") }
                .take(MAX_OTHER_STACK_LINES).forEach { sb.append(it).append("\n") }
        }
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
