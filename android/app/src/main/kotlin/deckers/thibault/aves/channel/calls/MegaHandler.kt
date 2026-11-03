package deckers.thibault.aves.channel.calls

import android.content.Context
import deckers.thibault.aves.channel.calls.Coresult.Companion.safe
import deckers.thibault.aves.mega.MegaApiException
import deckers.thibault.aves.mega.MegaBandwidthException
import deckers.thibault.aves.mega.MegaNode
import deckers.thibault.aves.mega.MegaRepository
import deckers.thibault.aves.model.provider.MegaImageProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class MegaHandler(private val context: Context) : MethodCallHandler {
    private val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAccount" -> ioScope.launch { safe(call, result, ::getAccount) }
            "login" -> ioScope.launch { safe(call, result, ::login) }
            "logout" -> ioScope.launch { safe(call, result, ::logout) }
            "listFolder" -> ioScope.launch { safe(call, result, ::listFolder) }
            "clearCache" -> ioScope.launch { safe(call, result, ::clearCache) }
            "getLocalFile" -> ioScope.launch { safe(call, result, ::getLocalFile) }
            else -> result.notImplemented()
        }
    }

    private fun reportError(result: MethodChannel.Result, method: String, e: Exception) {
        when (e) {
            is MegaApiException -> result.error("$method-mega", e.message, e.code)
            is MegaBandwidthException -> result.error("$method-quota", e.message, e.secondsLeft)
            else -> result.error("$method-exception", e.message, e.stackTraceToString())
        }
    }

    private fun getAccount(@Suppress("unused_parameter") call: MethodCall, result: MethodChannel.Result) {
        result.success(MegaRepository.currentEmail(context)?.let { hashMapOf("email" to it) })
    }

    private fun login(call: MethodCall, result: MethodChannel.Result) {
        val email = call.argument<String>("email")
        val password = call.argument<String>("password")
        val mfaCode = call.argument<String>("mfaCode")
        if (email.isNullOrBlank() || password.isNullOrEmpty()) {
            result.error("login-args", "missing arguments", null)
            return
        }
        try {
            val session = MegaRepository.login(context, email, password, mfaCode)
            result.success(hashMapOf("email" to session.email))
        } catch (e: Exception) {
            reportError(result, "login", e)
        }
    }

    private fun logout(@Suppress("unused_parameter") call: MethodCall, result: MethodChannel.Result) {
        MegaRepository.logout(context)
        result.success(true)
    }

    // downloads the file if needed, so that players can open it without blocking the main thread
    private fun getLocalFile(call: MethodCall, result: MethodChannel.Result) {
        val uri = call.argument<String>("uri")?.let { android.net.Uri.parse(it) }
        val handle = uri?.let { MegaRepository.handleFromUri(it) }
        if (handle == null) {
            result.error("getLocalFile-args", "invalid uri=$uri", null)
            return
        }
        try {
            val node = MegaRepository.getNode(context, handle)
            if (node == null) {
                result.error("getLocalFile-node", "no node for uri=$uri", null)
                return
            }
            result.success(MegaRepository.getFile(context, node).absolutePath)
        } catch (e: Exception) {
            reportError(result, "getLocalFile", e)
        }
    }

    private fun clearCache(@Suppress("unused_parameter") call: MethodCall, result: MethodChannel.Result) {
        MegaRepository.clearCache(context)
        result.success(true)
    }

    // lists the subfolders and media files of a folder (cloud drive root when no handle is given)
    private fun listFolder(call: MethodCall, result: MethodChannel.Result) {
        val requestedHandle = call.argument<String>("handle")
        val refresh = call.argument<Boolean>("refresh") ?: false
        try {
            MegaRepository.refreshNodes(context, force = refresh)
            val handle = requestedHandle ?: MegaRepository.rootHandle()
            val folder = handle?.let { MegaRepository.getNode(context, it) }
            if (folder == null || !folder.isFolder) {
                result.error("listFolder-missing", "folder not found for handle=$requestedHandle", null)
                return
            }
            val children = MegaRepository.getChildren(folder.handle)
            val folders = children.filter { it.isFolder }.sortedBy { it.name.lowercase() }.map { child ->
                val grandChildren = MegaRepository.getChildren(child.handle)
                hashMapOf(
                    "handle" to child.handle,
                    "name" to child.name,
                    "folderCount" to grandChildren.count { it.isFolder },
                    "mediaCount" to grandChildren.count { !it.isFolder && MegaRepository.isMedia(it.name) },
                    "coverUri" to grandChildren.firstOrNull { !it.isFolder && MegaRepository.isMedia(it.name) }?.let { MegaRepository.uriFor(context, it.handle).toString() },
                )
            }
            val files = children.filter { !it.isFolder && MegaRepository.isMedia(it.name) }.map(::fileFields)
            result.success(
                hashMapOf(
                    "handle" to folder.handle,
                    "name" to folder.name,
                    "isRoot" to (folder.type == MegaNode.TYPE_ROOT),
                    "path" to MegaRepository.pathOf(folder.handle).filter { it.type != MegaNode.TYPE_ROOT }.map {
                        hashMapOf("handle" to it.handle, "name" to it.name)
                    },
                    "folders" to folders,
                    "files" to files,
                )
            )
        } catch (e: Exception) {
            reportError(result, "listFolder", e)
        }
    }

    // basic fields, available without downloading anything
    private fun fileFields(node: MegaNode): Map<String, Any?> = (MegaRepository.getDetails(context, node.handle) ?: emptyMap()) + hashMapOf(
        "uri" to MegaRepository.uriFor(context, node.handle).toString(),
        "path" to MegaImageProvider.virtualPath(node),
        "sourceMimeType" to MegaRepository.mimeTypeFor(node.name),
        "title" to node.name,
        "sizeBytes" to node.size,
        "dateModifiedMillis" to (node.modifiedTime ?: node.timestamp) * 1000,
        "dateAddedSecs" to node.timestamp,
        "hasThumbnail" to node.fileAttributes.containsKey(MegaNode.FA_THUMBNAIL),
    )

    companion object {
        const val CHANNEL = "deckers.thibault/aves/mega"
    }
}
