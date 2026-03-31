package com.example.broastaky_full

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        printKeyHash()
    }

    private fun printKeyHash() {
        try {
            val pkgName = this.packageName
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(pkgName, PackageManager.GET_SIGNING_CERTIFICATES)
            } else {
                packageManager.getPackageInfo(pkgName, PackageManager.GET_SIGNATURES)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                // signingInfo may be null, handle safely
                val signingInfo = packageInfo.signingInfo
                if (signingInfo != null) {
                    val signers = signingInfo.apkContentsSigners
                    if (signers != null) {
                        for (sig in signers) {
                            val md = MessageDigest.getInstance("SHA")
                            md.update(sig.toByteArray())
                            val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                            Log.d("KeyHash", keyHash)
                        }
                    } else {
                        Log.e("KeyHash", "apkContentsSigners is null")
                    }
                } else {
                    Log.e("KeyHash", "signingInfo is null")
                }
            } else {
                // older devices: use signatures array
                val signatures = packageInfo.signatures
                if (signatures != null) {
                    for (sig in signatures) {
                        val md = MessageDigest.getInstance("SHA")
                        md.update(sig.toByteArray())
                        val keyHash = Base64.encodeToString(md.digest(), Base64.NO_WRAP)
                        Log.d("KeyHash", keyHash)
                    }
                } else {
                    Log.e("KeyHash", "signatures is null")
                }
            }
        } catch (e: Exception) {
            Log.e("KeyHash", "Failed to print keyhash", e)
        }
    }
}