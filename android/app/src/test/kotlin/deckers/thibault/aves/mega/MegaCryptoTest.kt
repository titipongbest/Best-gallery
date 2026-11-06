package deckers.thibault.aves.mega

import org.junit.jupiter.api.Assertions.assertArrayEquals
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Test

// vectors generated with `megajs` 1.3.9
class MegaCryptoTest {
    private fun hex(s: String) = s.chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    @Test
    fun base64RoundTrip() {
        for (len in 0..40) {
            val bytes = ByteArray(len) { (it * 37 + 11).toByte() }
            assertArrayEquals(bytes, MegaCrypto.b64Decode(MegaCrypto.b64Encode(bytes)))
        }
        assertEquals("-_8", MegaCrypto.b64Encode(byteArrayOf(0xFB.toByte(), 0xFF.toByte())))
    }

    @Test
    fun legacyPasswordKeyAndUserHash() {
        val pkey = MegaCrypto.prepareKeyV1("correct horse battery stäple".toByteArray())
        assertArrayEquals(hex("b17df8b8ceafcce8a67fbc1bbe2358fc"), pkey)
        assertEquals("znJzEbKmAUY", MegaCrypto.b64Encode(MegaCrypto.stringHash(pkey, "someone.long-address@example.com".toByteArray())))
    }

    @Test
    fun passwordKeyV2() {
        val derived = MegaCrypto.prepareKeyV2("correct horse battery stäple".toByteArray(), MegaCrypto.b64Decode("1Gizme4_x3tOXIVBwraHw6_KmETVwhhptF6cDEHYTV8"))
        assertArrayEquals(hex("756875466f1bb1d5d37ba14c6049657f45c8db54ab3958f04a30095c73b05b5a"), derived)
    }

    @Test
    fun attributes() {
        val key = MegaCrypto.b64Decode("UEbpT_USZd3oBcBzKDk0oGoRd_O1pQm-y5oRBAEnzYo")
        val json = "{\"n\":\"IMG_2024 ภาพ.jpg\",\"c\":\"AbCdEfGhIjKlMnOpQrStUvWxYzABCDEFGHIJKL\"}"
        val encrypted = "Jkus8rmaVh7reM3ub4kQgzZZ70C2cPHu15xCb8KJoxPnbi2-gSmqrARSrMwzVm4HNEc6-G8TiHapgyW7fMiNxQASX5DS0P-kKWSqjCXGTa4"
        assertEquals(json, MegaCrypto.decryptAttributes(key, encrypted))
        assertEquals(encrypted, MegaCrypto.encryptAttributes(key, json))
    }

    @Test
    fun nodeKeyUnwrapping() {
        val plain = MegaCrypto.decryptEcb(MegaCrypto.b64Decode("Z--m9Q5LlFaK2LbxMNSeUg"), MegaCrypto.b64Decode("OgK_23-BYvN1YclRszXiNexm3KkJi6jy7Tap4sGF3fw"))
        assertEquals("UEbpT_USZd3oBcBzKDk0oGoRd_O1pQm-y5oRBAEnzYo", MegaCrypto.b64Encode(plain))
    }

    @Test
    fun contentDecryption() {
        val key = MegaCrypto.b64Decode("KmfASGaXWUaHf81MCfE8IR-Iq38xWpK1z0nXNlW3WDk")
        val plain = MegaCrypto.b64Decode("b8L2Tkp5mEbpalliltnlTS16biBZycor3O80B6yDsMJnwo9R1h5jTUOamtTTOrNjOneBysotyydL2F_rYj3NaHSgzGax_UVsFfnd6PjYq02izA8r4NJnnbufebMOYXRD")
        val encrypted = MegaCrypto.b64Decode("BeNFxLQFvL01okbfQt5cyYLrwTZ6mcF_V71G2PVoZaSGbCGY2DeidXihen43TzqBXUnHGExmgKek4QdFe1AZoYRUJjETAJtpEdlr22zppauiyHj7BgAqfz0hk-__heXw")
        assertArrayEquals(plain, MegaCrypto.ctrCipher(key, 0).doFinal(encrypted))
        assertArrayEquals(plain.copyOfRange(32, plain.size), MegaCrypto.ctrCipher(key, 32).doFinal(encrypted.copyOfRange(32, encrypted.size)))
    }
}
