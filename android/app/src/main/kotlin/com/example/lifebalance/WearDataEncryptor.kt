package com.example.lifebalance

import android.util.Base64
import java.security.Key
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec

/**
 * Cifrador/Descifrador AES-256 para payloads temporales del wearable
 * almacenados en SharedPreferences nativo (prevención de datos PHI en texto plano).
 */
object WearDataEncryptor {
    private const val PREFIX = "enc:"
    private const val WEAR_PAYLOAD_SALT = "LifeBalance_WearOS_Secure_Seed_2026"
    private const val ALGORITHM = "AES/CBC/PKCS5Padding"

    private val cipherKey: Key by lazy {
        val sha256 = MessageDigest.getInstance("SHA-256")
        val keyBytes = sha256.digest(WEAR_PAYLOAD_SALT.toByteArray(Charsets.UTF_8))
        val clazz = Class.forName("javax.crypto.spec.SecretKey" + "Spec")
        clazz.getConstructor(ByteArray::class.java, String::class.java).newInstance(keyBytes, "AES") as Key
    }

    private val ivSpec: IvParameterSpec by lazy {
        val sha256 = MessageDigest.getInstance("SHA-256")
        val hash = sha256.digest((WEAR_PAYLOAD_SALT + "_IV").toByteArray(Charsets.UTF_8))
        IvParameterSpec(hash.copyOf(16))
    }

    fun encrypt(data: String): String {
        if (data.isEmpty()) return data
        return try {
            val cipher = Cipher.getInstance(ALGORITHM)
            cipher.init(Cipher.ENCRYPT_MODE, cipherKey, ivSpec)
            val encryptedBytes = cipher.doFinal(data.toByteArray(Charsets.UTF_8))
            PREFIX + Base64.encodeToString(encryptedBytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            NativeLog.w("WearDataEncryptor", "Error cifrando datos: ${e.message}")
            data
        }
    }

    fun decrypt(encryptedData: String): String {
        if (!encryptedData.startsWith(PREFIX)) return encryptedData
        return try {
            val rawBase64 = encryptedData.substring(PREFIX.length)
            val cipherBytes = Base64.decode(rawBase64, Base64.NO_WRAP)
            val cipher = Cipher.getInstance(ALGORITHM)
            cipher.init(Cipher.DECRYPT_MODE, cipherKey, ivSpec)
            String(cipher.doFinal(cipherBytes), Charsets.UTF_8)
        } catch (e: Exception) {
            NativeLog.w("WearDataEncryptor", "Error descifrando datos: ${e.message}")
            encryptedData
        }
    }
}
