package deckers.thibault.aves.mega

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import deckers.thibault.aves.model.EntryFields
import deckers.thibault.aves.utils.LogUtils
import org.json.JSONObject
import deckers.thibault.aves.utils.MimeTypes
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

// App-wide access to the MEGA account: session persistence, node tree cache, file & thumbnail caches.
object MegaRepository {
    private val LOG_TAG = LogUtils.createTag<MegaRepository>()

    private const val PREFS_NAME = "mega_session"
    private const val PREF_SESSION = "session"

    // node tree is refetched after this delay, or on explicit refresh
    private const val NODES_TTL_MILLIS = 10 * 60 * 1000L

    // cap for decrypted full size files kept on disk
    private const val FILE_CACHE_MAX_BYTES = 512L * 1024 * 1024

    private val client = MegaClient()
    private val lock = Any()
    private var loadedSession = false

    @Volatile
    private var nodes: Map<String, MegaNode> = emptyMap()

    @Volatile
    private var children: Map<String, List<MegaNode>> = emptyMap()

    @Volatile
    private var nodesFetchedAt = 0L

    // per-file locks, so that concurrent requests for the same file download it once
    private val fileLocks = ConcurrentHashMap<String, Any>()

    // session

    private fun prefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    private fun ensureSession(context: Context): MegaSession? {
        synchronized(lock) {
            if (!loadedSession) {
                loadedSession = true
                try {
                    prefs(context).getString(PREF_SESSION, null)?.let { MegaSession.fromJson(it) }?.let { client.session = it }
                } catch (e: Exception) {
                    Log.w(LOG_TAG, "failed to restore MEGA session", e)
                }
            }
            return client.session
        }
    }

    fun currentEmail(context: Context): String? = ensureSession(context)?.email

    fun login(context: Context, email: String, password: String, mfaCode: String?): MegaSession {
        synchronized(lock) {
            loadedSession = true
            val session = client.login(email, password, mfaCode)
            prefs(context).edit().putString(PREF_SESSION, session.toJson()).apply()
            clearNodes()
            return session
        }
    }

    fun logout(context: Context) {
        synchronized(lock) {
            loadedSession = true
            client.logout()
            prefs(context).edit().clear().apply()
            clearNodes()
        }
        clearCache(context)
    }

    private fun clearNodes() {
        nodes = emptyMap()
        children = emptyMap()
        nodesFetchedAt = 0
    }

    private fun requireSession(context: Context): MegaSession {
        return ensureSession(context) ?: throw MegaApiException(MegaApiException.ESID, MegaApiException.describe(MegaApiException.ESID))
    }

    // run an API call, dropping the stored session if MEGA reports it as expired
    private fun <T> withSession(context: Context, block: () -> T): T {
        requireSession(context)
        try {
            return block()
        } catch (e: MegaApiException) {
            if (e.code == MegaApiException.ESID) {
                synchronized(lock) {
                    client.session = null
                    prefs(context).edit().clear().apply()
                    clearNodes()
                }
            }
            throw e
        }
    }

    // nodes

    fun refreshNodes(context: Context, force: Boolean) {
        synchronized(lock) {
            val now = System.currentTimeMillis()
            if (!force && nodes.isNotEmpty() && now - nodesFetchedAt < NODES_TTL_MILLIS) return
            val fetched = withSession(context) { client.fetchNodes() }
            setNodes(fetched)
            nodesFetchedAt = now
        }
    }

    private fun setNodes(list: Collection<MegaNode>) {
        nodes = list.associateBy { it.handle }
        children = list.filter { it.parent != null }.groupBy { it.parent!! }
    }

    fun getNode(context: Context, handle: String): MegaNode? {
        nodes[handle]?.let { return it }
        refreshNodes(context, force = false)
        return nodes[handle]
    }

    fun rootHandle(): String? = nodes.values.firstOrNull { it.type == MegaNode.TYPE_ROOT }?.handle

    fun getChildren(handle: String): List<MegaNode> = children[handle] ?: emptyList()

    // path of folder names from the cloud drive root, e.g. `Cloud Drive/Photos/2024`
    fun pathOf(handle: String): List<MegaNode> {
        val path = ArrayList<MegaNode>()
        var current = nodes[handle]
        var guard = 0
        while (current != null && guard++ < 100) {
            path.add(0, current)
            current = current.parent?.let { nodes[it] }
        }
        return path
    }

    fun rename(context: Context, node: MegaNode, newName: String): MegaNode {
        val renamed = withSession(context) { client.rename(node, newName) }
        synchronized(lock) {
            val updated = HashMap(nodes)
            updated[renamed.handle] = renamed
            setNodes(updated.values)
        }
        return renamed
    }

    // file names in the same folder, to avoid duplicates (MEGA allows duplicate names)
    fun siblingNames(node: MegaNode): Set<String> {
        val parent = node.parent ?: return emptySet()
        return getChildren(parent).filter { it.handle != node.handle }.map { it.name }.toSet()
    }

    // content

    private fun cacheRoot(context: Context) = File(context.cacheDir, "mega")
    private fun filesDir(context: Context) = File(cacheRoot(context), "files").apply { mkdirs() }
    private fun attrsDir(context: Context) = File(cacheRoot(context), "attrs").apply { mkdirs() }
    private fun headsDir(context: Context) = File(cacheRoot(context), "heads").apply { mkdirs() }
    private fun detailsDir(context: Context) = File(cacheRoot(context), "details").apply { mkdirs() }

    // dimensions, orientation and dates read from files, so that folders open instantly the next time
    private val detailIntKeys = listOf(EntryFields.WIDTH, EntryFields.HEIGHT, EntryFields.SOURCE_ROTATION_DEGREES)
    private val detailLongKeys = listOf(EntryFields.SOURCE_DATE_TAKEN_MILLIS, EntryFields.DURATION_MILLIS)

    fun getDetails(context: Context, handle: String): Map<String, Any>? {
        val file = File(detailsDir(context), "$handle.json")
        if (!file.exists()) return null
        return try {
            val o = JSONObject(file.readText())
            val map = HashMap<String, Any>()
            detailIntKeys.forEach { key -> if (o.has(key)) map[key] = o.getInt(key) }
            detailLongKeys.forEach { key -> if (o.has(key)) map[key] = o.getLong(key) }
            map
        } catch (e: Exception) {
            Log.w(LOG_TAG, "failed to read cached details for handle=$handle", e)
            null
        }
    }

    fun saveDetails(context: Context, handle: String, fields: Map<String, Any?>) {
        try {
            val o = JSONObject()
            (detailIntKeys + detailLongKeys).forEach { key ->
                when (val value = fields[key]) {
                    is Number -> o.put(key, value.toLong())
                }
            }
            File(detailsDir(context), "$handle.json").writeText(o.toString())
        } catch (e: Exception) {
            Log.w(LOG_TAG, "failed to cache details for handle=$handle", e)
        }
    }

    fun clearCache(context: Context) {
        cacheRoot(context).deleteRecursively()
    }

    // MEGA file contents are immutable for a given handle, so the handle is a valid cache key
    fun getFile(context: Context, node: MegaNode): File {
        val target = File(filesDir(context), node.handle)
        val fileLock = fileLocks.getOrPut(node.handle) { Any() }
        synchronized(fileLock) {
            if (target.exists() && target.length() == node.size) {
                target.setLastModified(System.currentTimeMillis())
                return target
            }
            val temp = File(target.parentFile, "${node.handle}.part")
            try {
                withSession(context) {
                    FileOutputStream(temp).use { output -> client.download(node, output) }
                }
                if (!temp.renameTo(target)) throw java.io.IOException("failed to move downloaded file to cache")
            } finally {
                temp.delete()
            }
        }
        trimFileCache(context)
        return target
    }

    // first bytes of a file, enough to read dimensions and EXIF metadata in most cases
    fun getHead(context: Context, node: MegaNode, length: Long): File {
        val full = File(filesDir(context), node.handle)
        if (full.exists() && full.length() == node.size) return full
        val target = File(headsDir(context), "${node.handle}_$length")
        if (target.exists() && target.length() > 0) return target
        val temp = File(target.parentFile, "${target.name}.part")
        try {
            withSession(context) {
                FileOutputStream(temp).use { output ->
                    client.download(node, output, start = 0, end = (minOf(length, node.size) - 1).coerceAtLeast(0))
                }
            }
            temp.renameTo(target)
        } finally {
            temp.delete()
        }
        return target
    }

    fun getCachedFileAttribute(context: Context, node: MegaNode, type: Int): ByteArray? {
        if (!node.fileAttributes.containsKey(type)) return null
        val target = File(attrsDir(context), "${node.handle}_$type.jpg")
        if (target.exists() && target.length() > 0) return target.readBytes()
        val bytes = withSession(context) { client.getFileAttribute(node, type) } ?: return null
        try {
            target.writeBytes(bytes)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "failed to cache file attribute for handle=${node.handle}", e)
        }
        return bytes
    }

    private fun trimFileCache(context: Context) {
        val files = filesDir(context).listFiles()?.filter { it.isFile && !it.name.endsWith(".part") } ?: return
        var total = files.sumOf { it.length() }
        if (total <= FILE_CACHE_MAX_BYTES) return
        for (file in files.sortedBy { it.lastModified() }) {
            if (total <= FILE_CACHE_MAX_BYTES) break
            total -= file.length()
            file.delete()
        }
    }

    // URIs

    fun authority(context: Context) = "${context.packageName}.mega"

    fun uriFor(context: Context, handle: String): Uri = Uri.Builder()
        .scheme("content")
        .authority(authority(context))
        .appendPath("node")
        .appendPath(handle)
        .build()

    fun isMegaUri(context: Context, uri: Uri): Boolean = uri.scheme == "content" && uri.authority == authority(context)

    fun handleFromUri(uri: Uri): String? {
        val segments = uri.pathSegments
        return if (segments.size >= 2 && segments[0] == "node") segments[1] else null
    }

    fun mimeTypeFor(name: String): String? {
        val ext = name.substringAfterLast('.', "").lowercase(Locale.ROOT)
        if (ext.isEmpty()) return null
        return when (ext) {
            "jpg", "jpeg", "jpe", "jfif" -> MimeTypes.JPEG
            "png" -> MimeTypes.PNG
            "gif" -> MimeTypes.GIF
            "webp" -> MimeTypes.WEBP
            "heic", "heif" -> MimeTypes.HEIC
            "avif" -> "image/avif"
            "bmp" -> MimeTypes.BMP
            "tif", "tiff" -> MimeTypes.TIFF
            "dng" -> MimeTypes.DNG_ADOBE
            "mp4", "m4v" -> "video/mp4"
            "mov" -> "video/quicktime"
            "webm" -> "video/webm"
            "mkv" -> "video/x-matroska"
            "3gp" -> "video/3gpp"
            else -> android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)
        }
    }

    fun isMedia(name: String): Boolean {
        val mimeType = mimeTypeFor(name) ?: return false
        return mimeType.startsWith("image/") || mimeType.startsWith("video/")
    }
}
