package com.zxc.vpn

import android.app.Application
import android.util.Log
import java.io.File

class VpnApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        copyGeoFilesFromAssets()
    }

    private fun copyGeoFilesFromAssets() {
        val geoFiles = listOf("geoip.dat", "geosite.dat")

        geoFiles.forEach { fileName ->
            val destFile = File(filesDir, fileName)

            if (!destFile.exists()) {
                try {
                    assets.open(fileName).use { input ->
                        destFile.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    Log.d("VpnApplication", "Copied $fileName to ${destFile.absolutePath}")
                } catch (e: Exception) {
                    Log.e("VpnApplication", "Failed to copy $fileName", e)
                }
            } else {
                Log.d("VpnApplication", "$fileName already exists at ${destFile.absolutePath}")
            }
        }
    }
}