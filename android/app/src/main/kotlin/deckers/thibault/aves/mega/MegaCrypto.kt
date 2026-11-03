package deckers.thibault.aves.mega

import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.Mac
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

// Crypto primitives used by the MEGA protocol.
// Reference implementations: MEGA web client, `megajs`, `rclone` (go-mega).
// This file has no Android dependency, so that it can be unit tested on a plain JVM.
object MegaCrypto {
    private val ZERO_IV = ByteArray(16)

    // base64 (URL safe, without padding), as used everywhere by the MEGA API

    // hand-rolled because `java.util.Base64` requires API 26
    private const val B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    private val B64_REVERSE = IntArray(128) { -1 }.apply {
        B64_ALPHABET.forEachIndexed { i, c -> this[c.code] = i }
        this['+'.code] = 62
        this['/'.code] = 63
    }

    fun b64Encode(bytes: ByteArray): String {
        val sb = StringBuilder((bytes.size * 4 + 2) / 3)
        var i = 0
        while (i < bytes.size) {
            val b0 = bytes[i].toInt() and 0xFF
            val b1 = if (i + 1 < bytes.size) bytes[i + 1].toInt() and 0xFF else 0
            val b2 = if (i + 2 < bytes.size) bytes[i + 2].toInt() and 0xFF else 0
            val n = (b0 shl 16) or (b1 shl 8) or b2
            sb.append(B64_ALPHABET[(n shr 18) and 63])
            sb.append(B64_ALPHABET[(n shr 12) and 63])
            if (i + 1 < bytes.size) sb.append(B64_ALPHABET[(n shr 6) and 63])
            if (i + 2 < bytes.size) sb.append(B64_ALPHABET[n and 63])
            i += 3
        }
        return sb.toString()
    }

    fun b64Decode(s: String): ByteArray {
        val out = java.io.ByteArrayOutputStream(s.length * 3 / 4)
        var buffer = 0
        var bits = 0
        for (c in s) {
            if (c == '=' || c.isWhitespace()) continue
            val v = if (c.code < 128) B64_REVERSE[c.code] else -1
            require(v >= 0) { "invalid base64 character=$c" }
            buffer = (buffer shl 6) or v
            bits += 6
            if (bits >= 8) {
                bits -= 8
                out.write((buffer shr bits) and 0xFF)
            }
        }
        return out.toByteArray()
    }

    // AES-128

    private fun aes(mode: Int, transformation: String, key: ByteArray, data: ByteArray, iv: ByteArray? = null): ByteArray {
        val cipher = Cipher.getInstance(transformation)
        val keySpec = SecretKeySpec(key, "AES")
        if (iv != null) {
            cipher.init(mode, keySpec, IvParameterSpec(iv))
        } else {
            cipher.init(mode, keySpec)
        }
        return cipher.doFinal(data)
    }

    fun encryptEcb(key: ByteArray, data: ByteArray): ByteArray = aes(Cipher.ENCRYPT_MODE, "AES/ECB/NoPadding", key, padTo16(data))

    fun decryptEcb(key: ByteArray, data: ByteArray): ByteArray = aes(Cipher.DECRYPT_MODE, "AES/ECB/NoPadding", key, padTo16(data))

    fun encryptCbc(key: ByteArray, data: ByteArray): ByteArray = aes(Cipher.ENCRYPT_MODE, "AES/CBC/NoPadding", key, padTo16(data), ZERO_IV)

    fun decryptCbc(key: ByteArray, data: ByteArray): ByteArray = aes(Cipher.DECRYPT_MODE, "AES/CBC/NoPadding", key, padTo16(data), ZERO_IV)

    fun padTo16(data: ByteArray): ByteArray {
        val rem = data.size % 16
        return if (rem == 0) data else data.copyOf(data.size + 16 - rem)
    }

    // password derivation

    // legacy (v1) accounts
    fun prepareKeyV1(password: ByteArray): ByteArray {
        var pkey = byteArrayOf(
            0x93.toByte(), 0xC4.toByte(), 0x67, 0xE3.toByte(), 0x7D, 0xB0.toByte(), 0xC7.toByte(), 0xA4.toByte(),
            0xD1.toByte(), 0xBE.toByte(), 0x3F, 0x81.toByte(), 0x01, 0x52, 0xCB.toByte(), 0x56,
        )
        // pre-build the AES ciphers for each 16-byte block of the password
        val ciphers = (password.indices step 16).map { j ->
            val key = ByteArray(16)
            for (i in 0 until 16 step 4) {
                if (i + j < password.size) {
                    System.arraycopy(password, i + j, key, i, minOf(4, password.size - (i + j)))
                }
            }
            Cipher.getInstance("AES/ECB/NoPadding").apply { init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES")) }
        }
        repeat(65536) {
            for (cipher in ciphers) {
                pkey = cipher.doFinal(pkey)
            }
        }
        return pkey
    }

    // legacy (v1) accounts: user hash sent at login
    fun stringHash(key: ByteArray, s: ByteArray): ByteArray {
        val h32 = IntArray(4)
        var i = 0
        while (i < s.size) {
            val len = minOf(4, s.size - i)
            var v = 0
            for (k in 0 until 4) {
                v = v shl 8
                if (k < len) v = v or (s[i + k].toInt() and 0xFF)
            }
            h32[(i / 4) and 3] = h32[(i / 4) and 3] xor v
            i += 4
        }
        var hash = ByteBuffer.allocate(16).order(ByteOrder.BIG_ENDIAN).apply { h32.forEach { putInt(it) } }.array()
        val cipher = Cipher.getInstance("AES/ECB/NoPadding").apply { init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES")) }
        repeat(16384) { hash = cipher.doFinal(hash) }
        return hash.copyOfRange(0, 4) + hash.copyOfRange(8, 12)
    }

    // v2 accounts: returns 32 bytes, the first half is the password key, the second half is the user hash
    // PBKDF2-HMAC-SHA512, 100k iterations, 32 bytes
    // hand-rolled because `PBKDF2WithHmacSHA512` requires API 26
    fun prepareKeyV2(password: ByteArray, salt: ByteArray): ByteArray = pbkdf2HmacSha512(password, salt, 100000, 32)

    fun pbkdf2HmacSha512(password: ByteArray, salt: ByteArray, iterations: Int, length: Int): ByteArray {
        val mac = Mac.getInstance("HmacSHA512")
        // an empty key is rejected by `SecretKeySpec`, and MEGA does not allow empty passwords anyway
        require(password.isNotEmpty()) { "empty password" }
        mac.init(SecretKeySpec(password, "HmacSHA512"))
        val hLen = mac.macLength
        val blocks = (length + hLen - 1) / hLen
        val out = ByteArray(blocks * hLen)
        for (block in 1..blocks) {
            mac.update(salt)
            mac.update(ByteBuffer.allocate(4).putInt(block).array())
            var u = mac.doFinal()
            val t = u.copyOf()
            for (i in 1 until iterations) {
                u = mac.doFinal(u)
                for (k in t.indices) t[k] = (t[k].toInt() xor u[k].toInt()).toByte()
            }
            System.arraycopy(t, 0, out, (block - 1) * hLen, hLen)
        }
        return out.copyOf(length)
    }

    // node keys

    // file keys are 32 bytes: AES key XORed with (nonce + meta MAC)
    fun unmergeFileKey(key: ByteArray): ByteArray {
        if (key.size < 32) return key.copyOf(16)
        val aesKey = ByteArray(16)
        for (i in 0 until 16) {
            aesKey[i] = (key[i].toInt() xor key[i + 16].toInt()).toByte()
        }
        return aesKey
    }

    fun fileNonce(key: ByteArray): ByteArray = key.copyOfRange(16, 24)

    // initial counter block for AES-CTR, positioned at a 16-byte aligned offset
    fun ctrIv(nonce: ByteArray, offset: Long): ByteArray {
        val block = offset / 16
        return ByteBuffer.allocate(16).order(ByteOrder.BIG_ENDIAN).put(nonce, 0, 8).putLong(block).array()
    }

    fun ctrCipher(key: ByteArray, offset: Long): Cipher {
        require(offset % 16 == 0L) { "CTR offset must be 16-byte aligned" }
        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(unmergeFileKey(key), "AES"), IvParameterSpec(ctrIv(fileNonce(key), offset)))
        return cipher
    }

    // node attributes

    fun decryptAttributes(nodeKey: ByteArray, encrypted: String): String? {
        val bytes = try {
            decryptCbc(unmergeFileKey(nodeKey), b64Decode(encrypted))
        } catch (e: Exception) {
            return null
        }
        var end = 0
        while (end < bytes.size && bytes[end].toInt() != 0) end++
        val s = String(bytes, 0, end, Charsets.UTF_8)
        if (!s.startsWith("MEGA{\"")) return null
        return s.substring(4)
    }

    fun encryptAttributes(nodeKey: ByteArray, json: String): String {
        val bytes = "MEGA$json".toByteArray(Charsets.UTF_8)
        return b64Encode(encryptCbc(unmergeFileKey(nodeKey), bytes))
    }

    // RSA (session ID decryption at login)

    // reads a MEGA MPI: 2-byte big endian bit length, followed by the big endian magnitude
    fun readMpi(bytes: ByteArray, offset: Int): Pair<BigInteger, Int> {
        val bitLength = ((bytes[offset].toInt() and 0xFF) shl 8) or (bytes[offset + 1].toInt() and 0xFF)
        val byteLength = (bitLength + 7) shr 3
        val start = offset + 2
        val magnitude = bytes.copyOfRange(start, start + byteLength)
        return Pair(BigInteger(1, magnitude), start + byteLength)
    }

    class RsaPrivateKey(val p: BigInteger, val q: BigInteger, val d: BigInteger) {
        val n: BigInteger = p.multiply(q)
    }

    fun decodePrivateKey(privk: ByteArray): RsaPrivateKey {
        var offset = 0
        val values = ArrayList<BigInteger>()
        for (i in 0 until 4) {
            val (value, next) = readMpi(privk, offset)
            values.add(value)
            offset = next
        }
        return RsaPrivateKey(p = values[0], q = values[1], d = values[2])
    }

    fun rsaDecrypt(ciphertext: ByteArray, key: RsaPrivateKey): ByteArray {
        val (c, _) = readMpi(ciphertext, 0)
        val m = c.modPow(key.d, key.n)
        var bytes = m.toByteArray()
        // drop sign byte
        if (bytes.size > 1 && bytes[0].toInt() == 0) bytes = bytes.copyOfRange(1, bytes.size)
        return bytes
    }

    // hashcash (anti-abuse challenge occasionally required by the API)

    fun solveHashcash(challenge: String): String {
        val parts = challenge.split(":")
        require(parts.size >= 4 && parts[0] == "1") { "unsupported hashcash challenge=$challenge" }
        val easiness = parts[1].toInt()
        val tokenStr = parts[3]
        val base = ((easiness and 63) shl 1) + 1
        val shifts = (easiness shr 6) * 7 + 3
        val threshold = (base.toLong() shl shifts) and 0xFFFFFFFFL
        val token = b64Decode(tokenStr)
        val repeats = 262144
        val buffer = ByteArray(4 + repeats * 48)
        for (i in 0 until repeats) {
            System.arraycopy(token, 0, buffer, 4 + i * 48, minOf(48, token.size))
        }
        val digest = MessageDigest.getInstance("SHA-256")
        while (true) {
            val hash = digest.digest(buffer)
            val head = ByteBuffer.wrap(hash, 0, 4).order(ByteOrder.BIG_ENDIAN).int.toLong() and 0xFFFFFFFFL
            if (head <= threshold) {
                return "1:$tokenStr:${b64Encode(buffer.copyOfRange(0, 4))}"
            }
            var j = 0
            while (true) {
                buffer[j]++
                if (buffer[j++].toInt() != 0) break
            }
        }
    }
}
