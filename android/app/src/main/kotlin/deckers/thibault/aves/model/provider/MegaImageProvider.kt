package deckers.thibault.aves.model.provider

import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Log
import deckers.thibault.aves.mega.MegaNode
import deckers.thibault.aves.mega.MegaRepository
import deckers.thibault.aves.model.AvesEntry
import deckers.thibault.aves.model.EntryFields
import deckers.thibault.aves.model.FieldMap
import deckers.thibault.aves.model.SourceEntry
import deckers.thibault.aves.utils.LogUtils
import deckers.thibault.aves.utils.MimeTypes

// Entries stored in the MEGA cloud drive.
// They are identified by `content://<package>.mega/node/<handle>` URIs,
// and get a virtual path (`/MEGA/<folders>/<name>`) so that names, extensions and folders work as usual.
class MegaImageProvider : ImageProvider() {
    override fun fetchSingle(
        context: Context,
        sourceMimeType: String?,
        uri: Uri,
        allowUnsized: Boolean,
        callback: ImageOpCallback,
    ) {
        try {
            val handle = MegaRepository.handleFromUri(uri) ?: throw Exception("invalid MEGA uri=$uri")
            val node = MegaRepository.getNode(context, handle) ?: throw Exception("no MEGA node for uri=$uri")
            val fields = fetchFields(context, node, sourceMimeType)
            if (allowUnsized || isSized(fields) || MimeTypes.isVideo(fields[EntryFields.SOURCE_MIME_TYPE] as String)) {
                callback.onSuccess(fields)
            } else {
                callback.onFailure(Exception("entry has no size"))
            }
        } catch (e: Exception) {
            callback.onFailure(e)
        }
    }

    private fun isSized(fields: FieldMap) = ((fields[EntryFields.WIDTH] as Int?) ?: 0) > 0 && ((fields[EntryFields.HEIGHT] as Int?) ?: 0) > 0

    private fun fetchFields(context: Context, node: MegaNode, sourceMimeType: String?): FieldMap {
        val mimeType = MegaRepository.mimeTypeFor(node.name) ?: sourceMimeType ?: throw Exception("unknown MIME type for name=${node.name}")
        val isVideo = MimeTypes.isVideo(mimeType)

        // reuse details read previously
        val cached = MegaRepository.getDetails(context, node.handle)
        var probed: FieldMap? = cached?.let { HashMap<String, Any?>(it) }
        // read dimensions/orientation/date from the beginning of the file, to avoid downloading everything.
        // files probed before are not probed again, even when their dimensions could not be read
        if (probed == null) {
            for (length in if (isVideo) listOf(HEAD_LENGTH_LARGE) else listOf(HEAD_LENGTH, HEAD_LENGTH_LARGE)) {
                probed = probe(context, MegaRepository.getHead(context, node, length), mimeType)
                if (probed != null && isSized(probed)) break
            }
        }
        if ((probed == null || !isSized(probed)) && !isVideo && cached == null) {
            // e.g. metadata at the end of the file
            probed = probe(context, MegaRepository.getFile(context, node), mimeType)
        }
        val fields: FieldMap = probed ?: hashMapOf()
        if (!isSized(fields)) {
            // fallback to the preview aspect ratio, so that the entry can at least be displayed
            previewSize(context, node)?.let { (w, h) ->
                fields[EntryFields.WIDTH] = w
                fields[EntryFields.HEIGHT] = h
            }
        }
        if (cached == null) {
            MegaRepository.saveDetails(context, node.handle, fields)
        }

        fields[EntryFields.ORIGIN] = SourceEntry.ORIGIN_MEGA
        fields[EntryFields.URI] = MegaRepository.uriFor(context, node.handle).toString()
        fields[EntryFields.PATH] = virtualPath(node)
        fields[EntryFields.SOURCE_MIME_TYPE] = mimeType
        fields[EntryFields.TITLE] = node.name
        fields[EntryFields.SIZE_BYTES] = node.size
        val modifiedSecs = node.modifiedTime ?: node.timestamp
        fields[EntryFields.DATE_MODIFIED_MILLIS] = modifiedSecs * 1000
        fields[EntryFields.DATE_ADDED_SECS] = node.timestamp
        fields.remove(EntryFields.CONTENT_ID)
        return fields
    }

    private fun probe(context: Context, file: java.io.File, mimeType: String): FieldMap? = try {
        SourceEntry(SourceEntry.ORIGIN_FILE, Uri.fromFile(file), mimeType).fillPreCatalogMetadata(context).toMap()
    } catch (e: Exception) {
        Log.w(LOG_TAG, "failed to probe metadata from file=$file", e)
        null
    }

    private fun previewSize(context: Context, node: MegaNode): Pair<Int, Int>? {
        val bytes = try {
            MegaRepository.getCachedFileAttribute(context, node, MegaNode.FA_PREVIEW)
        } catch (_: Exception) {
            null
        } ?: return null
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
        return if (options.outWidth > 0 && options.outHeight > 0) Pair(options.outWidth, options.outHeight) else null
    }

    override suspend fun renameMultiple(
        context: Context,
        entriesToNewName: Map<AvesEntry, String>,
        isCancelledOp: CancelCheck,
        callback: ImageOpCallback,
    ) {
        try {
            MegaRepository.refreshNodes(context, force = false)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "failed to refresh MEGA nodes before renaming", e)
        }
        // names taken by this batch, by folder, so that two entries do not get the same new name
        val takenByFolder = HashMap<String, MutableSet<String>>()

        for ((entry, desiredName) in entriesToNewName) {
            val sourceUri = entry.uri
            val result: FieldMap = hashMapOf(
                "uri" to sourceUri.toString(),
                "success" to false,
            )
            try {
                if (isCancelledOp()) {
                    result["newFields"] = skippedFieldMap
                    result["success"] = true
                } else {
                    val handle = MegaRepository.handleFromUri(sourceUri) ?: throw Exception("invalid MEGA uri=$sourceUri")
                    val node = MegaRepository.getNode(context, handle) ?: throw Exception("no MEGA node for uri=$sourceUri")
                    val folder = node.parent ?: ""
                    val taken = takenByFolder.getOrPut(folder) { HashSet() }
                    val targetName = resolveName(node, desiredName, MegaRepository.siblingNames(node) + taken)
                    if (targetName == node.name) {
                        result["newFields"] = skippedFieldMap
                    } else {
                        val renamed = MegaRepository.rename(context, node, targetName)
                        taken.add(renamed.name)
                        result["newFields"] = hashMapOf<String, Any?>(
                            EntryFields.URI to sourceUri.toString(),
                            EntryFields.PATH to virtualPath(renamed),
                            EntryFields.TITLE to renamed.name,
                        )
                    }
                    result["success"] = true
                }
            } catch (e: Exception) {
                Log.w(LOG_TAG, "failed to rename MEGA entry uri=$sourceUri to name=$desiredName", e)
            }
            callback.onSuccess(result)
        }
    }

    // keeps the original extension, and appends ` (n)` on conflict
    private fun resolveName(node: MegaNode, desiredName: String, takenNames: Set<String>): String {
        val extension = node.name.substringAfterLast('.', "").let { if (it.isEmpty()) "" else ".$it" }
        var base = desiredName.trim()
        if (extension.isNotEmpty() && base.endsWith(extension, ignoreCase = true)) {
            base = base.substring(0, base.length - extension.length)
        }
        base = base.replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001F]"), "_").trimStart('.').trim()
        if (base.isEmpty()) base = createTimeStampFileName()

        var candidate = "$base$extension"
        if (candidate == node.name) return candidate
        val taken = takenNames.map { it.lowercase() }.toSet()
        var i = 1
        while (taken.contains(candidate.lowercase())) {
            candidate = "$base ($i)$extension"
            i++
        }
        return candidate
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<MegaImageProvider>()

        private const val HEAD_LENGTH = 128L * 1024
        private const val HEAD_LENGTH_LARGE = 1024L * 1024

        const val VIRTUAL_ROOT = "/MEGA"

        fun virtualPath(node: MegaNode): String {
            val folders = node.parent?.let { MegaRepository.pathOf(it) } ?: emptyList()
            // skip the cloud drive root itself
            val names = folders.filter { it.type != MegaNode.TYPE_ROOT }.map { sanitizeSegment(it.name) }
            return (listOf(VIRTUAL_ROOT) + names + sanitizeSegment(node.name)).joinToString("/")
        }

        private fun sanitizeSegment(name: String) = name.replace('/', '_')
    }
}
