package deckers.thibault.aves.mega

import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.SecureRandom
import java.util.concurrent.atomic.AtomicLong
import javax.crypto.CipherInputStream

class MegaApiException(val code: Int, message: String) : IOException(message) {
    companion object {
        const val EAGAIN = -3
        const val ERATELIMIT = -4
        const val ENOENT = -9
        const val EACCESS = -11
        const val EKEY = -14
        const val ESID = -15
        const val EBLOCKED = -16
        const val EOVERQUOTA = -17
        const val ETEMPUNAVAIL = -18
        const val EMFAREQUIRED = -26

        fun describe(code: Int): String = when (code) {
            -1 -> "EINTERNAL: internal error"
            -2 -> "EARGS: invalid arguments"
            EAGAIN -> "EAGAIN: temporary congestion, try again"
            ERATELIMIT -> "ERATELIMIT: too many requests, wait a moment"
            ENOENT -> "ENOENT: not found (wrong email or password?)"
            EACCESS -> "EACCESS: access denied"
            -12 -> "EEXIST: already exists"
            EKEY -> "EKEY: decryption failed"
            ESID -> "ESID: session expired, please log in again"
            EBLOCKED -> "EBLOCKED: account blocked"
            EOVERQUOTA -> "EOVERQUOTA: over quota"
            ETEMPUNAVAIL -> "ETEMPUNAVAIL: temporarily unavailable"
            EMFAREQUIRED -> "EMFAREQUIRED: two-factor authentication code required"
            else -> "MEGA error $code"
        }
    }
}

class MegaBandwidthException(val secondsLeft: Long?) : IOException("MEGA transfer quota exceeded" + (secondsLeft?.let { ", resets in ${it}s" } ?: ""))

// Session data needed to resume without the password.
// The master key is required to decrypt node keys, so it is stored along with the session ID.
data class MegaSession(
    val email: String,
    val sid: String,
    val masterKey: ByteArray,
    val userHandle: String,
) {
    fun toJson(): String = JSONObject().apply {
        put("email", email)
        put("sid", sid)
        put("k", MegaCrypto.b64Encode(masterKey))
        put("u", userHandle)
    }.toString()

    companion object {
        fun fromJson(json: String): MegaSession? = try {
            val o = JSONObject(json)
            MegaSession(
                email = o.getString("email"),
                sid = o.getString("sid"),
                masterKey = MegaCrypto.b64Decode(o.getString("k")),
                userHandle = o.getString("u"),
            )
        } catch (_: Exception) {
            null
        }
    }

    override fun equals(other: Any?): Boolean = other is MegaSession && sid == other.sid
    override fun hashCode(): Int = sid.hashCode()
}

data class MegaNode(
    val handle: String,
    val parent: String?,
    // 0: file, 1: folder, 2: cloud drive root, 3: inbox, 4: rubbish bin
    val type: Int,
    val name: String,
    val size: Long,
    // seconds since epoch, time of upload/creation on MEGA
    val timestamp: Long,
    // original file modification time from the fingerprint, in seconds, if any
    val modifiedTime: Long?,
    // decrypted node key: 16 bytes for folders, 32 bytes for files
    val key: ByteArray,
    // raw attributes, to preserve unknown fields when renaming
    val attributes: JSONObject,
    // file attribute handles, by type (0: thumbnail, 1: preview)
    val fileAttributes: Map<Int, String>,
) {
    val isFolder: Boolean get() = type != TYPE_FILE

    override fun equals(other: Any?): Boolean = other is MegaNode && handle == other.handle && name == other.name
    override fun hashCode(): Int = handle.hashCode()

    companion object {
        const val TYPE_FILE = 0
        const val TYPE_FOLDER = 1
        const val TYPE_ROOT = 2
        const val TYPE_INBOX = 3
        const val TYPE_RUBBISH = 4
        const val FA_THUMBNAIL = 0
        const val FA_PREVIEW = 1
    }
}

// Minimal client for the MEGA API (https://g.api.mega.co.nz/cs).
// Covers: login (v1 & v2 accounts, 2FA), session resume, node listing,
// attribute decryption, renaming, file download (with range) and thumbnails/previews.
class MegaClient(
    private val gateway: String = DEFAULT_GATEWAY,
    private val http: HttpTransport = UrlConnectionTransport(),
) {
    // request sequence number, randomly seeded as done by official clients
    private val seq = AtomicLong(SecureRandom().nextInt(Int.MAX_VALUE).toLong())

    @Volatile
    var session: MegaSession? = null

    // share keys (folder handle -> key) for folders shared by or with this account
    private val shareKeys = HashMap<String, ByteArray>()

    // API

    fun request(command: JSONObject): Any = requestBatch(JSONArray().put(command)).get(0)

    private fun requestBatch(commands: JSONArray, querySid: Boolean = true): JSONArray {
        var hashcash: String? = null
        var hashcashAttempts = 0
        var attempt = 0
        var requestId = seq.incrementAndGet()
        while (true) {
            // as done by official clients, a request retried with a hashcash solution keeps its sequence number
            if (hashcash == null && attempt > 0) requestId = seq.incrementAndGet()
            val query = StringBuilder("id=$requestId")
            val sid = session?.sid
            if (querySid && sid != null) query.append("&sid=").append(URLEncoder.encode(sid, "UTF-8"))
            val headers = HashMap<String, String>()
            headers["Content-Type"] = "application/json"
            headers["User-Agent"] = USER_AGENT
            hashcash?.let { headers["X-Hashcash"] = it }
            val response = http.post("${gateway}cs?$query", headers, commands.toString().toByteArray(Charsets.UTF_8))

            val challenge = response.headers["x-hashcash"]
            if (challenge != null && hashcashAttempts < MAX_RETRIES) {
                hashcash = MegaCrypto.solveHashcash(challenge)
                hashcashAttempts++
                continue
            }
            hashcash = null
            if (response.code != 200) {
                if (response.code in 500..599 && attempt < MAX_RETRIES) {
                    backoff(attempt++)
                    continue
                }
                val details = if (response.code == 402) {
                    " (hashcash challenge=${challenge ?: "missing"}, solved=$hashcashAttempts)"
                } else {
                    ""
                }
                throw IOException("MEGA API HTTP status=${response.code}$details")
            }
            val text = String(response.body, Charsets.UTF_8).trim()
            // a bare number is a global error (e.g. -3, -15)
            if (!text.startsWith("[")) {
                val code = text.toIntOrNull() ?: throw IOException("unexpected MEGA API response=$text")
                if (code == MegaApiException.EAGAIN && attempt < MAX_RETRIES) {
                    backoff(attempt++)
                    continue
                }
                throw MegaApiException(code, MegaApiException.describe(code))
            }
            val array = JSONArray(text)
            val first = array.opt(0)
            if (first is Number && first.toInt() == MegaApiException.EAGAIN && attempt < MAX_RETRIES) {
                backoff(attempt++)
                continue
            }
            for (i in 0 until array.length()) {
                val item = array.opt(i)
                if (item is Number && item.toInt() < 0) {
                    throw MegaApiException(item.toInt(), MegaApiException.describe(item.toInt()))
                }
            }
            return array
        }
    }

    private fun backoff(attempt: Int) {
        Thread.sleep(1000L shl (attempt + 1).coerceAtMost(5))
    }

    // login

    fun login(email: String, password: String, mfaCode: String? = null): MegaSession {
        val user = email.trim().lowercase()
        val passwordBytes = password.toByteArray(Charsets.UTF_8)
        val prelogin = request(JSONObject().put("a", "us0").put("user", user)) as JSONObject

        val passwordKey: ByteArray
        val userHash: String
        when (prelogin.optInt("v", 1)) {
            1 -> {
                passwordKey = MegaCrypto.prepareKeyV1(passwordBytes)
                userHash = MegaCrypto.b64Encode(MegaCrypto.stringHash(passwordKey, user.toByteArray(Charsets.UTF_8)))
            }

            2 -> {
                val derived = MegaCrypto.prepareKeyV2(passwordBytes, MegaCrypto.b64Decode(prelogin.getString("s")))
                passwordKey = derived.copyOfRange(0, 16)
                userHash = MegaCrypto.b64Encode(derived.copyOfRange(16, 32))
            }

            else -> throw IOException("unsupported MEGA account version")
        }

        val command = JSONObject().put("a", "us").put("user", user).put("uh", userHash)
        mfaCode?.trim()?.takeIf { it.isNotEmpty() }?.let { command.put("mfa", it) }
        session = null
        val res = request(command) as JSONObject

        val masterKey = MegaCrypto.decryptEcb(passwordKey, MegaCrypto.b64Decode(res.getString("k")))
        val sid: String = when {
            res.has("csid") -> {
                val privk = MegaCrypto.decryptEcb(masterKey, MegaCrypto.b64Decode(res.getString("privk")))
                val rsaKey = MegaCrypto.decodePrivateKey(privk)
                val decrypted = MegaCrypto.rsaDecrypt(MegaCrypto.b64Decode(res.getString("csid")), rsaKey)
                MegaCrypto.b64Encode(decrypted.copyOf(43))
            }

            res.has("tsid") -> {
                // temporary session for accounts without RSA key pair
                val tsid = MegaCrypto.b64Decode(res.getString("tsid"))
                val check = MegaCrypto.encryptEcb(masterKey, tsid.copyOfRange(0, 16))
                if (!check.contentEquals(tsid.copyOfRange(tsid.size - 16, tsid.size))) throw IOException("invalid credentials")
                res.getString("tsid")
            }

            else -> throw IOException("unexpected login response")
        }
        session = MegaSession(email = user, sid = sid, masterKey = masterKey, userHandle = res.optString("u", ""))

        if (session!!.userHandle.isEmpty()) {
            val ug = request(JSONObject().put("a", "ug")) as JSONObject
            session = session!!.copy(userHandle = ug.getString("u"))
        }
        return session!!
    }

    fun logout() {
        try {
            if (session != null) request(JSONObject().put("a", "sml"))
        } catch (_: Exception) {
            // ignore, the session is dropped locally anyway
        }
        session = null
        shareKeys.clear()
    }

    // nodes

    fun fetchNodes(): List<MegaNode> {
        val s = session ?: throw MegaApiException(MegaApiException.ESID, MegaApiException.describe(MegaApiException.ESID))
        val res = request(JSONObject().put("a", "f").put("c", 1)) as JSONObject

        shareKeys.clear()
        res.optJSONArray("ok")?.let { ok ->
            for (i in 0 until ok.length()) {
                val share = ok.getJSONObject(i)
                val h = share.getString("h")
                try {
                    shareKeys[h] = MegaCrypto.decryptEcb(s.masterKey, MegaCrypto.b64Decode(share.getString("k")))
                } catch (_: Exception) {
                }
            }
        }

        val f = res.getJSONArray("f")
        val nodes = ArrayList<MegaNode>(f.length())
        for (i in 0 until f.length()) {
            parseNode(f.getJSONObject(i), s)?.let { nodes.add(it) }
        }
        return nodes
    }

    private fun parseNode(o: JSONObject, s: MegaSession): MegaNode? {
        val handle = o.getString("h")
        val type = o.optInt("t", 0)
        when (type) {
            MegaNode.TYPE_ROOT, MegaNode.TYPE_INBOX, MegaNode.TYPE_RUBBISH -> return MegaNode(
                handle = handle,
                parent = null,
                type = type,
                name = when (type) {
                    MegaNode.TYPE_ROOT -> "Cloud Drive"
                    MegaNode.TYPE_INBOX -> "Inbox"
                    else -> "Rubbish Bin"
                },
                size = 0,
                timestamp = o.optLong("ts", 0),
                modifiedTime = null,
                key = ByteArray(16),
                attributes = JSONObject(),
                fileAttributes = emptyMap(),
            )
        }

        val k = o.optString("k", "")
        if (k.isEmpty()) return null
        val key = decryptNodeKey(k, s) ?: return null
        if (type == MegaNode.TYPE_FILE && key.size < 32) return null

        val attrJson = o.optString("a", "").takeIf { it.isNotEmpty() }?.let { MegaCrypto.decryptAttributes(key, it) } ?: return null
        val attributes = try {
            JSONObject(attrJson)
        } catch (_: Exception) {
            return null
        }

        // share key for this folder, if it is the root of an outgoing share
        o.optString("sk", "").takeIf { it.isNotEmpty() }?.let { sk ->
            try {
                shareKeys[handle] = MegaCrypto.decryptEcb(s.masterKey, MegaCrypto.b64Decode(sk))
            } catch (_: Exception) {
            }
        }

        return MegaNode(
            handle = handle,
            parent = o.optString("p", "").takeIf { it.isNotEmpty() },
            type = type,
            name = attributes.optString("n", handle),
            size = o.optLong("s", 0),
            timestamp = o.optLong("ts", 0),
            modifiedTime = attributes.optString("c", "").takeIf { it.isNotEmpty() }?.let(::fingerprintModifiedTime),
            key = key,
            attributes = attributes,
            fileAttributes = parseFileAttributes(o.optString("fa", "")),
        )
    }

    private fun decryptNodeKey(k: String, s: MegaSession): ByteArray? {
        // format: `<owner or share handle>:<encrypted key>` separated by `/`
        for (part in k.split("/")) {
            val sep = part.indexOf(':')
            if (sep < 0) continue
            val id = part.substring(0, sep)
            val encrypted = MegaCrypto.b64Decode(part.substring(sep + 1))
            // keys longer than 32 bytes are RSA encrypted (pending shares), not supported here
            if (encrypted.size > 32) continue
            val decryptionKey = when (id) {
                s.userHandle -> s.masterKey
                else -> shareKeys[id]
            } ?: continue
            try {
                return MegaCrypto.decryptEcb(decryptionKey, encrypted)
            } catch (_: Exception) {
            }
        }
        return null
    }

    // e.g. `123:0*AbCdEfGhIjK/123:1*LmNoPqRsTuV`
    private fun parseFileAttributes(fa: String): Map<Int, String> {
        if (fa.isEmpty()) return emptyMap()
        val map = HashMap<Int, String>()
        for (part in fa.split("/")) {
            val colon = part.indexOf(':')
            val star = part.indexOf('*')
            if (colon < 0 || star < colon) continue
            val type = part.substring(colon + 1, star).toIntOrNull() ?: continue
            map[type] = part.substring(star + 1)
        }
        return map
    }

    // file fingerprint: base64 of [4 x 4-byte CRC chunks][1 byte length][mtime as little endian bytes]
    private fun fingerprintModifiedTime(c: String): Long? = try {
        val bytes = MegaCrypto.b64Decode(c)
        if (bytes.size < 18) {
            null
        } else {
            val len = bytes[16].toInt() and 0xFF
            if (len < 1 || len > 8 || 17 + len > bytes.size) {
                null
            } else {
                var t = 0L
                for (i in len - 1 downTo 0) {
                    t = (t shl 8) or (bytes[17 + i].toLong() and 0xFF)
                }
                t
            }
        }
    } catch (_: Exception) {
        null
    }

    // rename

    fun rename(node: MegaNode, newName: String): MegaNode {
        val attributes = JSONObject(node.attributes.toString()).put("n", newName)
        val at = MegaCrypto.encryptAttributes(node.key, attributes.toString())
        request(JSONObject().put("a", "a").put("n", node.handle).put("at", at).put("i", randomRequestId()))
        return node.copy(name = newName, attributes = attributes)
    }

    private fun randomRequestId(): String {
        val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
        val random = SecureRandom()
        return (1..10).map { chars[random.nextInt(chars.length)] }.joinToString("")
    }

    // download

    data class DownloadInfo(val url: String, val size: Long)

    fun getDownloadInfo(node: MegaNode): DownloadInfo {
        val res = request(JSONObject().put("a", "g").put("g", 1).put("ssl", 2).put("n", node.handle)) as JSONObject
        val url = res.optString("g", "")
        if (!url.startsWith("http")) throw IOException("MEGA did not return a download URL, possibly rate limited")
        return DownloadInfo(url, res.optLong("s", node.size))
    }

    // decrypted stream from `start` (inclusive) to `end` (inclusive, or end of file when null)
    fun openDecryptedStream(node: MegaNode, info: DownloadInfo, start: Long = 0, end: Long? = null): InputStream {
        val alignedStart = start - start % 16
        val last = end ?: (info.size - 1)
        if (info.size == 0L || alignedStart > last) return java.io.ByteArrayInputStream(ByteArray(0))
        val response = http.get("${info.url}/$alignedStart-$last")
        val skip = (start - alignedStart).toInt()
        val decrypted = CipherInputStream(response, MegaCrypto.ctrCipher(node.key, alignedStart))
        if (skip > 0) {
            var skipped = 0L
            while (skipped < skip) {
                val n = decrypted.skip(skip - skipped)
                if (n <= 0) {
                    if (decrypted.read() == -1) break
                    skipped++
                } else {
                    skipped += n
                }
            }
        }
        return decrypted
    }

    fun download(node: MegaNode, output: OutputStream, start: Long = 0, end: Long? = null) {
        val info = getDownloadInfo(node)
        openDecryptedStream(node, info, start, end).use { it.copyTo(output, 64 * 1024) }
    }

    // thumbnails (type 0, ~120x120 square crop JPEG) and previews (type 1, ~1000px JPEG)

    fun getFileAttribute(node: MegaNode, type: Int): ByteArray? {
        val faHandle = node.fileAttributes[type] ?: return null
        val res = request(JSONObject().put("a", "ufa").put("fah", faHandle).put("ssl", 2).put("r", 1)) as JSONObject
        val url = res.optString("p", "")
        if (!url.startsWith("http")) return null
        val handleBytes = MegaCrypto.b64Decode(faHandle)
        val response = http.post(url, mapOf("Content-Type" to "application/octet-stream"), handleBytes)
        if (response.code != 200) return null
        val body = response.body
        // response: [8-byte handle][4-byte little endian length][encrypted data]
        val encrypted = if (body.size >= 12) {
            val len = ByteBuffer.wrap(body, 8, 4).order(ByteOrder.LITTLE_ENDIAN).int
            if (len > 0 && 12 + len <= body.size && body.copyOfRange(0, 8).contentEquals(handleBytes)) {
                body.copyOfRange(12, 12 + len)
            } else {
                body
            }
        } else {
            return null
        }
        return MegaCrypto.decryptCbc(MegaCrypto.unmergeFileKey(node.key), encrypted)
    }

    companion object {
        const val DEFAULT_GATEWAY = "https://g.api.mega.co.nz/"
        private const val MAX_RETRIES = 5
        private const val USER_AGENT = "BestGallery/2.1"
    }
}

// HTTP abstraction, so that the client can be tested without network

class HttpResponse(val code: Int, val headers: Map<String, String>, val body: ByteArray)

interface HttpTransport {
    fun post(url: String, headers: Map<String, String>, body: ByteArray): HttpResponse

    // streaming GET, throws on non-2xx statuses
    fun get(url: String): InputStream
}

class UrlConnectionTransport : HttpTransport {
    override fun post(url: String, headers: Map<String, String>, body: ByteArray): HttpResponse {
        val connection = URL(url).openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.connectTimeout = 30_000
            connection.readTimeout = 60_000
            headers.forEach { (k, v) -> connection.setRequestProperty(k, v) }
            connection.setFixedLengthStreamingMode(body.size)
            connection.outputStream.use { it.write(body) }
            val code = connection.responseCode
            val responseHeaders = HashMap<String, String>()
            connection.headerFields.forEach { (k, v) -> if (k != null && v.isNotEmpty()) responseHeaders[k.lowercase()] = v.first() }
            val stream = if (code >= 400) connection.errorStream else connection.inputStream
            val bytes = stream?.use { input ->
                ByteArrayOutputStream().also { input.copyTo(it) }.toByteArray()
            } ?: ByteArray(0)
            return HttpResponse(code, responseHeaders, bytes)
        } finally {
            connection.disconnect()
        }
    }

    override fun get(url: String): InputStream {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 30_000
        connection.readTimeout = 60_000
        val code = connection.responseCode
        if (code == 509) {
            val left = connection.getHeaderField("X-MEGA-Time-Left")?.toLongOrNull()
            connection.disconnect()
            throw MegaBandwidthException(left)
        }
        if (code !in 200..299) {
            connection.disconnect()
            throw IOException("MEGA download HTTP status=$code")
        }
        return connection.inputStream
    }
}
