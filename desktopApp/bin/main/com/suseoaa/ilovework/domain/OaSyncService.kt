package com.suseoaa.ilovework.domain

import java.awt.Desktop
import java.net.URI
import java.net.URLEncoder
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse
import java.security.MessageDigest
import java.time.Instant
import java.time.ZoneId
import java.util.Base64

object OaSyncService {

    // Simple class for returning auth config
    data class AuthSession(
        val authUrl: String,
        val codeVerifier: String
    )

    data class AttendanceResult(
        val date: String,
        val startHour: Int,
        val startMinute: Int,
        val endHour: Int?,
        val endMinute: Int?
    )

    fun generateAuthSession(): AuthSession {
        // Generate random code verifier
        val charPool = ('a'..'z') + ('A'..'Z') + ('0'..'9') + '-' + '_' + '.' + '~'
        val codeVerifier = (1..50).map { charPool.random() }.joinToString("")

        // Generate challenge
        val digest = MessageDigest.getInstance("SHA-256").digest(codeVerifier.toByteArray(Charsets.US_ASCII))
        val codeChallenge = Base64.getUrlEncoder().withoutPadding().encodeToString(digest)

        val state = (1..10).map { charPool.random() }.joinToString("")

        val url = "https://fuzzid.com/oauth" +
                "?response_type=code" +
                "&client_id=74" +
                "&code_challenge=${URLEncoder.encode(codeChallenge, "UTF-8")}" +
                "&code_challenge_method=S256" +
                "&redirect_uri=${URLEncoder.encode("http://localhost:10010/callback", "UTF-8")}" +
                "&state=${URLEncoder.encode(state, "UTF-8")}" +
                "&scope=openid" +
                "&resource=${URLEncoder.encode("https://oa.jinuotec.com/mcp/admin", "UTF-8")}"

        return AuthSession(url, codeVerifier)
    }

    fun openBrowser(url: String) {
        try {
            val uri = URI(url)
            val desktop = if (Desktop.isDesktopSupported()) Desktop.getDesktop() else null
            if (desktop != null && desktop.isSupported(Desktop.Action.BROWSE)) {
                desktop.browse(uri)
            } else {
                Runtime.getRuntime().exec(arrayOf("open", url))
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun exchangeToken(code: String, verifier: String): String? {
        try {
            val client = HttpClient.newHttpClient()
            val form = mapOf(
                "grant_type" to "authorization_code",
                "client_id" to "74",
                "code" to code,
                "redirect_uri" to "http://localhost:10010/callback",
                "code_verifier" to verifier
            ).map { (k, v) -> "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}" }
                .joinToString("&")

            val request = HttpRequest.newBuilder()
                .uri(URI.create("https://fuzzid.com/api/oauth/token"))
                .header("Content-Type", "application/x-www-form-urlencoded")
                .POST(HttpRequest.BodyPublishers.ofString(form))
                .build()

            val response = client.send(request, HttpResponse.BodyHandlers.ofString())
            if (response.statusCode() == 200) {
                val body = response.body()
                val tokenRegex = """\"access_token\"\s*:\s*\"([^\"]+)\"""".toRegex()
                return tokenRegex.find(body)?.groupValues?.get(1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    fun syncClockInTimes(accessToken: String, userName: String): AttendanceResult? {
        try {
            val client = HttpClient.newHttpClient()
            val dateEnd = java.time.LocalDate.now().toString()
            val dateStart = java.time.LocalDate.now().minusDays(7).toString()

            val url = "https://oa.jinuotec.com/api/admin/open/report/daily" +
                    "?userName=${URLEncoder.encode(userName, "UTF-8")}" +
                    "&dateStart=${URLEncoder.encode(dateStart, "UTF-8")}" +
                    "&dateEnd=${URLEncoder.encode(dateEnd, "UTF-8")}" +
                    "&page=1" +
                    "&count=10"

            val request = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .header("Authorization", "Bearer $accessToken")
                .GET()
                .build()

            val response = client.send(request, HttpResponse.BodyHandlers.ofString())
            if (response.statusCode() == 200) {
                val body = response.body()
                // Simple regex parser for items in daily report
                // JSON structure: "date":"YYYY-MM-DD" ... "inTime":XXX,"outTime":YYY
                val itemRegex = """\{"date":"([^"]+)".*?"inTime":(\d+),"outTime":(\d+)""".toRegex()
                val records = itemRegex.findAll(body).map { match ->
                    val date = match.groupValues[1]
                    val inTime = match.groupValues[2].toLong()
                    val outTime = match.groupValues[3].toLong()
                    Triple(date, inTime, outTime)
                }.toList()

                // Find the latest record where inTime > 0
                val latestRecord = records
                    .filter { it.second > 0 }
                    .maxByOrNull { it.first } // latest date first

                if (latestRecord != null) {
                    val date = latestRecord.first
                    val inTime = latestRecord.second
                    val outTime = latestRecord.third

                    val inInstant = Instant.ofEpochSecond(inTime)
                    val inDateTime = inInstant.atZone(ZoneId.systemDefault())
                    val startHour = inDateTime.hour
                    val startMinute = inDateTime.minute

                    val endHour: Int?
                    val endMinute: Int?
                    if (outTime > 0) {
                        val outInstant = Instant.ofEpochSecond(outTime)
                        val outDateTime = outInstant.atZone(ZoneId.systemDefault())
                        endHour = outDateTime.hour
                        endMinute = outDateTime.minute
                    } else {
                        endHour = null
                        endMinute = null
                    }

                    return AttendanceResult(date, startHour, startMinute, endHour, endMinute)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }
}
