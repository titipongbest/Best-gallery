package deckers.thibault.aves.mega

import android.content.ContentProvider
import android.content.ContentValues
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.graphics.Point
import android.net.Uri
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Log
import deckers.thibault.aves.utils.LogUtils
import java.io.File
import java.io.FileNotFoundException

// Serves decrypted MEGA files as `content://<package>.mega/node/<handle>`,
// so that the rest of the app (decoding, metadata, sharing) can handle them like any other content.
// Files are downloaded and decrypted on first access, then served from the cache.
class MegaContentProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    private fun nodeFor(uri: Uri): MegaNode {
        val context = context ?: throw FileNotFoundException("no context")
        val handle = MegaRepository.handleFromUri(uri) ?: throw FileNotFoundException("invalid MEGA uri=$uri")
        val node: MegaNode? = try {
            MegaRepository.getNode(context, handle)
        } catch (e: Exception) {
            throw FileNotFoundException("failed to get MEGA node for uri=$uri: ${e.message}")
        }
        return node ?: throw FileNotFoundException("no MEGA node for uri=$uri")
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor {
        val node = nodeFor(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE, COLUMN_MIME_TYPE)
        val row = columns.map { column ->
            when (column) {
                OpenableColumns.DISPLAY_NAME -> node.name
                OpenableColumns.SIZE -> node.size
                COLUMN_MIME_TYPE -> MegaRepository.mimeTypeFor(node.name)
                else -> null
            }
        }
        return MatrixCursor(columns, 1).apply { addRow(row) }
    }

    override fun getType(uri: Uri): String? = try {
        MegaRepository.mimeTypeFor(nodeFor(uri).name)
    } catch (_: Exception) {
        null
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("MEGA content is read only")
        val context = context ?: throw FileNotFoundException("no context")
        val node = nodeFor(uri)
        val file: File = try {
            MegaRepository.getFile(context, node)
        } catch (e: Exception) {
            Log.w(LOG_TAG, "failed to download MEGA file for uri=$uri", e)
            throw FileNotFoundException("failed to download MEGA file: ${e.message}")
        }
        return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    // used by `ContentResolver.loadThumbnail()`: serve MEGA thumbnails/previews instead of downloading the full file
    override fun openTypedAssetFile(uri: Uri, mimeTypeFilter: String, opts: Bundle?, signal: CancellationSignal?): AssetFileDescriptor? {
        val context = context ?: throw FileNotFoundException("no context")
        val size = opts?.let {
            @Suppress("DEPRECATION")
            it.getParcelable<Point>(EXTRA_SIZE)
        }
        if (size != null) {
            val node = nodeFor(uri)
            val type = if (maxOf(size.x, size.y) <= THUMBNAIL_MAX_DIMENSION) MegaNode.FA_THUMBNAIL else MegaNode.FA_PREVIEW
            val bytes = try {
                MegaRepository.getCachedFileAttribute(context, node, type)
                    ?: MegaRepository.getCachedFileAttribute(context, node, if (type == MegaNode.FA_THUMBNAIL) MegaNode.FA_PREVIEW else MegaNode.FA_THUMBNAIL)
            } catch (e: Exception) {
                Log.w(LOG_TAG, "failed to get MEGA thumbnail for uri=$uri", e)
                null
            }
            if (bytes != null) {
                val pipe = ParcelFileDescriptor.createPipe()
                Thread {
                    try {
                        ParcelFileDescriptor.AutoCloseOutputStream(pipe[1]).use { it.write(bytes) }
                    } catch (e: Exception) {
                        Log.w(LOG_TAG, "failed to write thumbnail to pipe", e)
                    }
                }.start()
                return AssetFileDescriptor(pipe[0], 0, AssetFileDescriptor.UNKNOWN_LENGTH)
            }
        }
        return super.openTypedAssetFile(uri, mimeTypeFilter, opts, signal)
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    companion object {
        private val LOG_TAG = LogUtils.createTag<MegaContentProvider>()
        private const val COLUMN_MIME_TYPE = "mime_type"

        // same as `ContentResolver.EXTRA_SIZE`, which requires API 29
        private const val EXTRA_SIZE = "android.content.extra.SIZE"

        // MEGA thumbnails are 120x120 crops, previews are up to 1000px
        const val THUMBNAIL_MAX_DIMENSION = 240
    }
}
