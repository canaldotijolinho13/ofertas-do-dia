#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/br/com/lista
mkdir -p app/src/main/assets
mkdir -p app/src/main/res/drawable
mkdir -p app/src/main/res/values

cat > settings.gradle.kts <<'GF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "OfertasDoDia"
include(":app")
GF

cat > build.gradle.kts <<'GF'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
GF

cat > gradle.properties <<'GF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
GF

cat > app/build.gradle.kts <<'GF'
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "br.com.ofertas"
    compileSdk = 35
    defaultConfig {
        applicationId = "br.com.ofertas"
        minSdk = 24
        targetSdk = 35
        versionCode = 2
        versionName = "1.1"
    }
    signingConfigs {
        create("release") {
            storeFile = file("../keystore.jks")
            storePassword = "ofertas123"
            keyAlias = "ofertas"
            keyPassword = "ofertas123"
        }
    }
    buildFeatures {
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
dependencies {
    implementation("androidx.webkit:webkit:1.12.1")
}
GF

cat > app/src/main/AndroidManifest.xml <<'GF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:allowBackup="true"
        android:icon="@drawable/ic_launcher"
        android:label="Ofertas do Dia"
        android:roundIcon="@drawable/ic_launcher"
        android:theme="@style/AppTheme">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:configChanges="orientation|screenSize|keyboardHidden"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
GF

cat > app/src/main/res/values/themes.xml <<'GF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="AppTheme" parent="android:Theme.Material.Light.NoActionBar">
        <item name="android:statusBarColor">#16A34A</item>
    </style>
</resources>
GF

cat > app/src/main/res/drawable/ic_launcher.xml <<'GF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp"
    android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#16A34A" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#FFFFFF" android:pathData="M54,22l10,20 22,3 -16,16 4,22 -20,-11 -20,11 4,-22 -16,-16 22,-3z" />
</vector>
GF

cat > app/src/main/java/br/com/ofertas/MainActivity.kt <<'GF'
package br.com.ofertas

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.WebViewAssetLoader
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : Activity() {

    private lateinit var web: WebView

    private val fontes = mapOf(
        "epic" to "https://store-site-backend-static.akamaized.net/currentFreeGames?country=BR&locale=pt-BR",
        "gog" to "https://www.gog.com/games/ajax/filtered?mediaType=game&price=free&sort=popularity&page=1",
        "steam" to "https://store.steampowered.com/api/featuredcategories?cc=BR&l=portuguese",
        "cheapshark" to "https://www.cheapshark.com/api/1.0/deals?storeID=1,2,3,7,13,15,21,23,25,27,30&sortBy=Deal%20Rating&pageSize=60&upperPrice=60",
        "thunder" to "https://thunderkeys.com/collections/all-products/products.json?limit=250",
        "ig" to "https://www.instant-gaming.com/pt/promocoes/",
        "nuuvem" to "https://www.nuuvem.com/br-pt/catalog?sort=discount"
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val loader = WebViewAssetLoader.Builder()
            .addPathHandler("/assets/", WebViewAssetLoader.AssetsPathHandler(this))
            .build()

        web = WebView(this)
        web.layoutParams = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )

        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            allowFileAccess = false
            setSupportZoom(false)
        }

        web.addJavascriptInterface(Bridge(), "AndroidBridge")

        web.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest
            ): WebResourceResponse? = loader.shouldInterceptRequest(request.url)

            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean {
                val url = request.url
                return if (url.host == "appassets.androidplatform.net") {
                    false
                } else {
                    startActivity(Intent(Intent.ACTION_VIEW, url))
                    true
                }
            }
        }

        setContentView(web)
        web.loadUrl("https://appassets.androidplatform.net/assets/index.html")
    }

    override fun onBackPressed() {
        if (this::web.isInitialized && web.canGoBack()) web.goBack() else super.onBackPressed()
    }

    inner class Bridge {
        @JavascriptInterface
        fun buscar(fonte: String) {
            val endereco = fontes[fonte] ?: return
            val html = fonte == "ig" || fonte == "nuuvem"
            Thread {
                try {
                    val conexao = URL(endereco).openConnection() as HttpURLConnection
                    conexao.connectTimeout = 15000
                    conexao.readTimeout = 25000
                    conexao.setRequestProperty(
                        "User-Agent",
                        "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36"
                    )
                    conexao.setRequestProperty("Accept-Language", "pt-BR,pt;q=0.9")
                    conexao.setRequestProperty("Accept", if (html) "text/html" else "application/json")
                    val texto = conexao.inputStream.bufferedReader().use { it.readText() }
                    val literal = JSONObject.quote(texto)
                    val funcao = if (html) "window.receberHtml" else "window.receber"
                    runOnUiThread {
                        if (this@MainActivity::web.isInitialized) {
                            web.evaluateJavascript(funcao + "('" + fonte + "', " + literal + ")", null)
                        }
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        if (this@MainActivity::web.isInitialized) {
                            web.evaluateJavascript("window.falhou('" + fonte + "')", null)
                        }
                    }
                }
            }.start()
        }
    }
}
GF

cat app/src/main/assets/p1.txt app/src/main/assets/p2.txt app/src/main/assets/p3.txt app/src/main/assets/p4.txt > app/src/main/assets/index.html
rm app/src/main/assets/p1.txt app/src/main/assets/p2.txt app/src/main/assets/p3.txt app/src/main/assets/p4.txt
echo "projeto montado"
