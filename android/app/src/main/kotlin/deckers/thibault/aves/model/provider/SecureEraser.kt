package deckers.thibault.aves.model.provider

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import deckers.thibault.aves.storage.StorageUtils
import deckers.thibault.aves.utils.LogUtils
import deckers.thibault.aves.utils.UriUtils.isContentScheme
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.channels.FileChannel
import java.security.SecureRandom

// Best gallery: overwrite file content with random data before deletion.
//
// Note that on flash storage (wear levelling, file system copy-on-write, TRIM)
// overwriting a file does not guarantee that every physical copy of its blocks is erased,
// but it prevents recovery of the content through the file system and common recovery tools.
object SecureEraser {
    private val LOG_TAG = LogUtils.createTag<SecureEraser>()

    private const val BUFFER_SIZE = 256 * 1024

    // returns whether the content was overwritten
    fun overwrite(context: Context, file: File, uri: Uri): Boolean {
        val length = file.length()
        if (length <= 0) return false

        // direct file access
        try {
            if (file.canWrite()) {
                RandomAccessFile(file, "rw").use { raf ->
                    overwrite(raf.channel, length)
                }
                Log.d(LOG_TAG, "overwrote file at path=$file")
                return true
            }
        } catch (ex: Exception) {
            Log.w(LOG_TAG, "failed to overwrite file at path=$file", ex)
        }

        // via Media Store content URI
        if (uri.isContentScheme && overwriteViaDescriptor(context, uri, length)) {
            Log.d(LOG_TAG, "overwrote content at uri=$uri")
            return true
        }

        // via SAF document
        try {
            val df = StorageUtils.getDocumentFileForExistingFile(context, filePath = file.path, mediaUri = uri)
            if (df != null && overwriteViaDescriptor(context, df.uri, length)) {
                Log.d(LOG_TAG, "overwrote document at uri=${df.uri}")
                return true
            }
        } catch (ex: Exception) {
            Log.w(LOG_TAG, "failed to overwrite document for path=$file", ex)
        }

        Log.w(LOG_TAG, "could not overwrite file at path=$file before deletion")
        return false
    }

    private fun overwriteViaDescriptor(context: Context, uri: Uri, length: Long): Boolean {
        try {
            // "rw" mode does not truncate the file, so blocks are overwritten in place
            val pfd: ParcelFileDescriptor = context.contentResolver.openFileDescriptor(uri, "rw") ?: return false
            pfd.use {
                FileOutputStream(it.fileDescriptor).use { output ->
                    overwrite(output.channel, length)
                }
            }
            return true
        } catch (ex: Exception) {
            Log.w(LOG_TAG, "failed to overwrite content at uri=$uri", ex)
        }
        return false
    }

    private fun overwrite(channel: FileChannel, length: Long) {
        val random = SecureRandom()
        val bytes = ByteArray(BUFFER_SIZE)
        val buffer = ByteBuffer.wrap(bytes)
        var position = 0L
        while (position < length) {
            random.nextBytes(bytes)
            val count = minOf(BUFFER_SIZE.toLong(), length - position).toInt()
            buffer.clear()
            buffer.limit(count)
            while (buffer.hasRemaining()) {
                position += channel.write(buffer, position)
            }
        }
        channel.force(true)
    }
}
