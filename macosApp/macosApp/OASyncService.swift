import Foundation
import CryptoKit
import AppKit

// MARK: - OA Sync Service

/// Handles OAuth 2.1 PKCE flow and OA attendance API for the native macOS app.
/// The user opens a browser for authorization, copies the callback URL, and pastes
/// it back into the app to complete the token exchange (no local HTTP server needed).
class OASyncService: ObservableObject {

    static let shared = OASyncService()

    // OAuth constants
    private let clientId = "74"
    private let redirectUri = "http://localhost:10010/callback"
    private let authBaseUrl = "https://fuzzid.com/oauth"
    private let tokenUrl = "https://fuzzid.com/api/oauth/token"
    private let attendanceUrl = "https://oa.jinuotec.com/api/admin/open/report/daily"

    // Session state kept in memory during the auth flow
    private(set) var codeVerifier: String = ""

    // MARK: - Step 1: Generate auth URL & open browser

    /// Generates a PKCE code verifier + challenge, builds the auth URL, and opens it in Safari.
    /// Returns the auth URL string (for display / debugging).
    @discardableResult
    func startAuthFlow() -> String {
        // Generate code verifier (43–128 unreserved chars)
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        codeVerifier = String((0..<64).map { _ in chars.randomElement()! })

        // S256 challenge: BASE64URL(SHA256(ASCII(verifier)))
        let verifierData = Data(codeVerifier.utf8)
        let hashData = SHA256.hash(data: verifierData)
        let codeChallenge = Data(hashData)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: ["="])

        let state = String((0..<16).map { _ in chars.randomElement()! })

        var components = URLComponents(string: authBaseUrl)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "openid"),
            URLQueryItem(name: "resource", value: "https://oa.jinuotec.com/mcp/admin"),
        ]

        let urlString = components.url!.absoluteString
        NSWorkspace.shared.open(URL(string: urlString)!)
        return urlString
    }

    // MARK: - Step 2: Parse callback URL pasted by user

    /// Extracts the `code` parameter from the callback URL pasted by the user.
    func extractCode(from callbackUrl: String) -> String? {
        guard let url = URL(string: callbackUrl),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value
        else { return nil }
        return code
    }

    // MARK: - Step 3: Exchange code for access token

    /// Exchanges the authorization code for an access token using the PKCE verifier.
    func exchangeToken(code: String) async throws -> String {
        guard !codeVerifier.isEmpty else {
            throw OAError.missingVerifier
        }

        var request = URLRequest(url: URL(string: tokenUrl)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params: [String: String] = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectUri,
            "code_verifier": codeVerifier,
        ]
        request.httpBody = params
            .map { "\($0.key.urlEncoded)=\($0.value.urlEncoded)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OAError.tokenExchangeFailed(body)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let token = json?["access_token"] as? String else {
            throw OAError.tokenNotFound
        }
        return token
    }

    // MARK: - Step 4: Fetch today's clock-in time (Via MCP)
    
    /// Fetches the most recent attendance record for the given user name via MCP JSON-RPC.
    func fetchAttendance(accessToken: String, userName: String) async throws -> AttendanceRecord {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)
        let weekAgo = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -7 * 86400)).prefix(10)
        
        let mcpUrl = URL(string: "https://oa.jinuotec.com/mcp/admin")!
        
        // 1. Send MCP Initialize to get Session Cookies
        var initReq = URLRequest(url: mcpUrl)
        initReq.httpMethod = "POST"
        initReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        initReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        initReq.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        initReq.setValue("2025-11-25", forHTTPHeaderField: "mcp-protocol-version")
        
        let initBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 0,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-11-25",
                "capabilities": [:],
                "clientInfo": ["name": "macosApp", "version": "1.0"]
            ]
        ]
        initReq.httpBody = try JSONSerialization.data(withJSONObject: initBody)
        
        let (initData, initResponse) = try await URLSession.shared.data(for: initReq)
        guard let httpInitResponse = initResponse as? HTTPURLResponse, httpInitResponse.statusCode == 200 else {
            let body = String(data: initData, encoding: .utf8) ?? ""
            throw OAError.apiFailed("MCP Initialize Failed: \(body)")
        }
        
        // Extract Cookies
        var cookiesValue = ""
        if let headerFields = httpInitResponse.allHeaderFields as? [String: String],
           let url = initResponse.url {
            let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
            cookiesValue = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
        }
        
        // 2. Call the Tool
        var callReq = URLRequest(url: mcpUrl)
        callReq.httpMethod = "POST"
        callReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        callReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        callReq.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        callReq.setValue("2025-11-25", forHTTPHeaderField: "mcp-protocol-version")
        if !cookiesValue.isEmpty {
            callReq.setValue(cookiesValue, forHTTPHeaderField: "Cookie")
        }
        
        let callBody: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": [
                "name": "invoke_tool",
                "arguments": [
                    "tool_name": "oa_service_attendance_getDailyReport",
                    "arguments": [
                        "userName": userName,
                        "dateStart": String(weekAgo),
                        "dateEnd": String(today),
                        "page": 1,
                        "count": 10
                    ]
                ]
            ]
        ]
        callReq.httpBody = try JSONSerialization.data(withJSONObject: callBody)
        
        let (data, response) = try await URLSession.shared.data(for: callReq)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OAError.apiFailed("MCP Tool Call Failed: \(body)")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        // Parse MCP Response
        // The result structure for tool call is: {"result": {"content": [{"text": "...json string..."}]}}
        guard let result = json?["result"] as? [String: Any],
              let contentList = result["content"] as? [[String: Any]],
              let firstContent = contentList.first,
              let textPayload = firstContent["text"] as? String else {
            throw OAError.apiFailed("Invalid MCP Response Format")
        }
        
        let payloadData = textPayload.data(using: .utf8) ?? Data()
        let payloadJson = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        
        // Search items in the inner JSON
        guard let items = (payloadJson?["data"] as? [String: Any])?["items"] as? [[String: Any]] ?? payloadJson?["items"] as? [[String: Any]] else {
            throw OAError.noAttendanceData
        }
        return try parseLatestRecord(from: items)
    }

    private func parseLatestRecord(from items: [[String: Any]]) throws -> AttendanceRecord {
        // Find most recent record with a valid inTime
        let valid = items.compactMap { item -> (String, Int, Int?)? in
            guard let date = item["date"] as? String,
                  let inTime = item["inTime"] as? Int, inTime > 0
            else { return nil }
            let outTime = item["outTime"] as? Int
            return (date, inTime, outTime)
        }.sorted { $0.0 > $1.0 } // descending by date

        guard let latest = valid.first else {
            throw OAError.noAttendanceData
        }

        let inDate = Date(timeIntervalSince1970: TimeInterval(latest.1))
        let cal = Calendar.current
        let startHour = cal.component(.hour, from: inDate)
        let startMinute = cal.component(.minute, from: inDate)

        var endHour: Int? = nil
        var endMinute: Int? = nil
        if let outTime = latest.2, outTime > 0 {
            let outDate = Date(timeIntervalSince1970: TimeInterval(outTime))
            endHour = cal.component(.hour, from: outDate)
            endMinute = cal.component(.minute, from: outDate)
        }

        return AttendanceRecord(
            date: latest.0,
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
        )
    }
}

// MARK: - Supporting Types

struct AttendanceRecord {
    let date: String
    let startHour: Int
    let startMinute: Int
    let endHour: Int?
    let endMinute: Int?
}

enum OAError: LocalizedError {
    case missingVerifier
    case tokenExchangeFailed(String)
    case tokenNotFound
    case apiFailed(String)
    case noAttendanceData

    var errorDescription: String? {
        switch self {
        case .missingVerifier:          return "缺少 code_verifier，请重新发起授权"
        case .tokenExchangeFailed(let s): return "获取 Token 失败：\(s)"
        case .tokenNotFound:            return "响应中未找到 access_token"
        case .apiFailed(let s):         return "OA 接口请求失败：\(s)"
        case .noAttendanceData:         return "未找到打卡记录"
        }
    }
}

// MARK: - String URL encoding helper

private extension String {
    var urlEncoded: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "+", with: "%2B") ?? self
    }
}

import WidgetKit

@MainActor
class OABackgroundSyncer: ObservableObject {
    static let shared = OABackgroundSyncer()
    
    private var timer: Timer?
    
    private init() {
        start()
    }
    
    func start() {
        stop()
        // Run every 5 minutes (300 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndSync()
            }
        }
        // Also fire once immediately just in case
        Task {
            await checkAndSync()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func checkAndSync() async {
        var cfg = ConfigStore.load()
        
        guard cfg.enableAutoOASync, cfg.oaConnected, !cfg.oaAccessToken.isEmpty, !cfg.oaUserName.isEmpty else {
            return
        }
        
        let now = Date()
        let cal = Calendar.current
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let todayStr = df.string(from: now)
        
        // If already synced today, do nothing
        if cfg.lastOASyncDate == todayStr {
            return
        }
        
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let currentTimeMinutes = hour * 60 + minute
        
        // Time windows: 09:00 - 11:30 (540 - 690) OR 13:00 - 16:30 (780 - 990)
        let isMorningWindow = currentTimeMinutes >= 540 && currentTimeMinutes <= 690
        let isAfternoonWindow = currentTimeMinutes >= 780 && currentTimeMinutes <= 990
        
        if isMorningWindow || isAfternoonWindow {
            do {
                let record = try await OASyncService.shared.fetchAttendance(
                    accessToken: cfg.oaAccessToken,
                    userName: cfg.oaUserName
                )
                
                cfg.workStartHour = record.startHour
                cfg.workStartMinute = record.startMinute
                cfg.todayClockInTime = String(format: "%02d:%02d", record.startHour, record.startMinute)
                
                // Calculate auto off-work time
                let totalStartMinutes = record.startHour * 60 + record.startMinute
                let totalWorkMinutes = Int(cfg.workHoursPerDay * 60)
                let totalEndMinutes = totalStartMinutes + totalWorkMinutes
                cfg.workEndHour = (totalEndMinutes / 60) % 24
                cfg.workEndMinute = totalEndMinutes % 60
                
                cfg.lastOASyncDate = todayStr
                
                ConfigStore.save(cfg)
                WidgetCenter.shared.reloadAllTimelines()
                NotificationManager.shared.scheduleReminders(config: cfg)
                
                print("OABackgroundSyncer: Successfully synced and updated config.")
            } catch {
                print("OABackgroundSyncer: Sync failed - \(error.localizedDescription)")
            }
        }
    }
}
