package com.mk.messenger

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import android.view.View
import android.webkit.CookieManager
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.core.content.FileProvider
import java.io.File

class MainActivity : Activity() {
    private lateinit var webView: WebView
    private var uploadCallback: ValueCallback<Array<Uri>>? = null
    private var cameraOutput: Uri? = null
    private val pickerRequest = 4102
    private val cameraRequest = 4103
    private val siteUrl = "https://mk-messenger-khant-min-htet2.vercel.app/"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = Color.rgb(8, 26, 51)
        window.navigationBarColor = Color.rgb(243, 246, 250)
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        webView = WebView(this)
        webView.setBackgroundColor(Color.WHITE)
        webView.settings.javaScriptEnabled = true
        webView.settings.domStorageEnabled = true
        webView.settings.databaseEnabled = true
        webView.settings.allowFileAccess = false
        webView.settings.allowContentAccess = true
        webView.settings.javaScriptCanOpenWindowsAutomatically = false
        webView.settings.setSupportMultipleWindows(false)
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val host = request?.url?.host ?: return false
                return !(host == "mk-messenger-khant-min-htet2.vercel.app" ||
                    host == "lpjmsncnyeyliskwvrgj.supabase.co")
            }
        }
        webView.webChromeClient = object : WebChromeClient() {
            override fun onShowFileChooser(
                view: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                uploadCallback?.onReceiveValue(null)
                uploadCallback = filePathCallback
                val imageInput = fileChooserParams?.acceptTypes
                    ?.any { it.contains("image", ignoreCase = true) || it == "*/*" } ?: true
                if (!imageInput) {
                    finishUpload(null)
                    Toast.makeText(this@MainActivity, "Please select an image.", Toast.LENGTH_SHORT).show()
                    return true
                }
                if (fileChooserParams?.isCaptureEnabled == true) openCamera() else openGalleryPicker()
                return true
            }
        }
        CookieManager.getInstance().setAcceptCookie(true)
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
        setContentView(webView)
        if (savedInstanceState == null) webView.loadUrl(siteUrl) else webView.restoreState(savedInstanceState)
    }

    private fun openGalleryPicker() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= 33) {
                Intent(MediaStore.ACTION_PICK_IMAGES).apply { type = "image/*" }
            } else {
                Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
            }
            startActivityForResult(intent, pickerRequest)
        } catch (_: Exception) {
            try {
                val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                    addCategory(Intent.CATEGORY_OPENABLE)
                }
                startActivityForResult(fallback, pickerRequest)
            } catch (_: Exception) {
                finishUpload(null)
                Toast.makeText(this, "Unable to open photo gallery.", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun openCamera() {
        try {
            val directory = File(cacheDir, "camera")
            if (!directory.exists()) directory.mkdirs()
            val photo = File(directory, "profile-${System.currentTimeMillis()}.jpg")
            cameraOutput = FileProvider.getUriForFile(this, "com.mk.messenger.fileprovider", photo)
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, cameraOutput)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            }
            startActivityForResult(intent, cameraRequest)
        } catch (_: Exception) {
            finishUpload(null)
            Toast.makeText(this, "Unable to open camera.", Toast.LENGTH_LONG).show()
        }
    }

    @Deprecated("Handled for WebView file chooser")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            pickerRequest -> {
                val uri = if (resultCode == RESULT_OK) data?.data else null
                finishUpload(uri?.let { arrayOf(it) })
            }
            cameraRequest -> {
                val uri = if (resultCode == RESULT_OK) cameraOutput else null
                finishUpload(uri?.let { arrayOf(it) })
                cameraOutput = null
            }
        }
    }

    private fun finishUpload(result: Array<Uri>?) {
        uploadCallback?.onReceiveValue(result)
        uploadCallback = null
    }

    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) webView.goBack() else super.onBackPressed()
    }

    override fun onSaveInstanceState(outState: Bundle) {
        if (::webView.isInitialized) webView.saveState(outState)
        super.onSaveInstanceState(outState)
    }

    override fun onDestroy() {
        uploadCallback?.onReceiveValue(null)
        uploadCallback = null
        if (::webView.isInitialized) webView.destroy()
        super.onDestroy()
    }
}
