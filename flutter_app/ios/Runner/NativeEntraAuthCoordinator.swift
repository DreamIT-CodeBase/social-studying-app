import AuthenticationServices
import CryptoKit
import Flutter
import Foundation
import Security
import UIKit

/// Owns the complete Entra authorization-code + PKCE transaction on iOS.
///
/// This intentionally does not delegate interactive login to flutter_appauth.
/// It supports both callback paths seen in the field: the callback delivered
/// directly to ASWebAuthenticationSession and the custom URL opening the app's
/// UIApplication/UIScene delegate.
final class NativeEntraAuthCoordinator: NSObject,
  ASWebAuthenticationPresentationContextProviding
{
  static let shared = NativeEntraAuthCoordinator()

  private var session: ASWebAuthenticationSession?
  private var pending: PendingAuthorization?
  private var flutterResult: FlutterResult?
  private var processingCallback = false
  private var timeoutWorkItem: DispatchWorkItem?

  private override init() {}

  func signIn(arguments: Any?, result: @escaping FlutterResult) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard session == nil, flutterResult == nil else {
      result(FlutterError(
        code: "entra_sign_in_in_progress",
        message: "A Microsoft sign-in is already in progress.",
        details: nil
      ))
      return
    }
    guard let arguments = arguments as? [String: Any],
          let clientID = arguments["clientId"] as? String,
          let tenantID = arguments["tenantId"] as? String,
          let tenantSubdomain = arguments["tenantSubdomain"] as? String,
          let redirectURI = arguments["redirectUri"] as? String,
          let redirectURL = URL(string: redirectURI),
          let redirectScheme = redirectURL.scheme,
          let scopes = arguments["scopes"] as? [String]
    else {
      result(FlutterError(
        code: "invalid_entra_configuration",
        message: "The Microsoft sign-in configuration is incomplete.",
        details: nil
      ))
      return
    }

    let verifier = Self.randomURLSafeString(byteCount: 48)
    let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    let state = Self.randomURLSafeString(byteCount: 32)
    let nonce = Self.randomURLSafeString(byteCount: 32)
    let authority = "https://\(tenantSubdomain).ciamlogin.com/\(tenantID)/oauth2/v2.0"

    guard var authorization = URLComponents(string: "\(authority)/authorize"),
          let tokenURL = URL(string: "\(authority)/token")
    else {
      result(FlutterError(code: "invalid_entra_authority", message: "Could not create the Entra authority URL.", details: nil))
      return
    }
    authorization.queryItems = [
      URLQueryItem(name: "client_id", value: clientID),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "redirect_uri", value: redirectURI),
      URLQueryItem(name: "response_mode", value: "query"),
      URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "code_challenge", value: challenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "state", value: state),
      URLQueryItem(name: "nonce", value: nonce),
      URLQueryItem(name: "prompt", value: "login"),
    ]
    guard let authorizationURL = authorization.url else {
      result(FlutterError(code: "invalid_entra_authorization_url", message: "Could not create the Entra sign-in URL.", details: nil))
      return
    }

    pending = PendingAuthorization(
      clientID: clientID,
      redirectURI: redirectURI,
      redirectScheme: redirectScheme,
      state: state,
      verifier: verifier,
      tokenURL: tokenURL,
      scopes: scopes
    )
    flutterResult = result
    processingCallback = false
    NSLog("Native Entra sign-in starting with redirect scheme %@", redirectScheme)

    let webSession = ASWebAuthenticationSession(
      url: authorizationURL,
      callbackURLScheme: redirectScheme
    ) { [weak self] callbackURL, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let callbackURL {
          self.processCallback(callbackURL)
        } else if !self.processingCallback {
          let nsError = error as NSError?
          self.finishWithError(
            code: nsError?.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
              ? "entra_sign_in_cancelled"
              : "entra_web_session_failed",
            message: error?.localizedDescription ?? "The Microsoft sign-in window closed before returning an authorization code.",
            details: nsError.map { ["domain": $0.domain, "code": $0.code] }
          )
        }
      }
    }
    webSession.presentationContextProvider = self
    webSession.prefersEphemeralWebBrowserSession = false
    session = webSession

    guard webSession.start() else {
      finishWithError(
        code: "entra_web_session_start_failed",
        message: "iOS could not start the Microsoft sign-in session.",
        details: nil
      )
      return
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self, self.flutterResult != nil else { return }
      self.session?.cancel()
      self.finishWithError(
        code: "entra_sign_in_timeout",
        message: "Microsoft sign-in did not return to the app within two minutes.",
        details: nil
      )
    }
    timeoutWorkItem = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 115, execute: timeout)
  }

  /// Fallback for iOS versions/configurations that open the custom scheme as a
  /// normal app URL instead of completing ASWebAuthenticationSession directly.
  @discardableResult
  func handleRedirectURL(_ url: URL) -> Bool {
    guard let pending,
          url.scheme?.caseInsensitiveCompare(pending.redirectScheme) == .orderedSame
    else { return false }
    NSLog("Native Entra sign-in captured delegate callback")
    DispatchQueue.main.async { [weak self] in self?.processCallback(url) }
    return true
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
      return keyWindow
    }
    return scenes.first?.windows.first ?? ASPresentationAnchor()
  }

  private func processCallback(_ url: URL) {
    guard !processingCallback, let pending else { return }
    processingCallback = true
    NSLog("Native Entra sign-in processing authorization callback")

    let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    let values = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
    guard values["state"] == pending.state else {
      finishWithError(code: "entra_state_mismatch", message: "Microsoft returned an invalid OAuth state value.", details: nil)
      return
    }
    if let oauthError = values["error"] {
      finishWithError(
        code: oauthError,
        message: values["error_description"] ?? "Microsoft rejected the sign-in request.",
        details: nil
      )
      return
    }
    guard let code = values["code"], !code.isEmpty else {
      finishWithError(code: "entra_missing_authorization_code", message: "Microsoft returned without an authorization code.", details: nil)
      return
    }

    // If the custom scheme woke the app normally, close the still-active web
    // session. Its cancellation callback is ignored because processingCallback
    // has already been set.
    session?.cancel()
    exchangeCode(code, pending: pending)
  }

  private func exchangeCode(_ code: String, pending: PendingAuthorization) {
    var request = URLRequest(url: pending.tokenURL)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.httpBody = Self.formEncode([
      "client_id": pending.clientID,
      "grant_type": "authorization_code",
      "code": code,
      "redirect_uri": pending.redirectURI,
      "code_verifier": pending.verifier,
      "scope": pending.scopes.joined(separator: " "),
    ])

    URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error {
          self.finishWithError(code: "entra_token_network_error", message: error.localizedDescription, details: nil)
          return
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
          self.finishWithError(code: "entra_invalid_token_response", message: "Microsoft returned an unreadable token response (HTTP \(status)).", details: nil)
          return
        }
        guard (200..<300).contains(status), let idToken = json["id_token"] as? String else {
          self.finishWithError(
            code: json["error"] as? String ?? "entra_token_exchange_failed",
            message: json["error_description"] as? String ?? "Microsoft token exchange failed (HTTP \(status)).",
            details: ["httpStatus": status]
          )
          return
        }
        let expiresIn = (json["expires_in"] as? NSNumber)?.doubleValue
        var payload: [String: Any] = [
          "accessToken": json["access_token"] as? String ?? "",
          "refreshToken": json["refresh_token"] as? String ?? "",
          "idToken": idToken,
          "tokenType": json["token_type"] as? String ?? "Bearer",
          "scopes": (json["scope"] as? String ?? pending.scopes.joined(separator: " ")).split(separator: " ").map(String.init),
        ]
        if let expiresIn {
          payload["expiresAtMilliseconds"] = Int(Date().addingTimeInterval(expiresIn).timeIntervalSince1970 * 1000)
        }
        self.finishSuccessfully(payload)
      }
    }.resume()
  }

  private func finishSuccessfully(_ payload: [String: Any]) {
    NSLog("Native Entra sign-in token exchange completed")
    let result = flutterResult
    cleanUp()
    result?(payload)
  }

  private func finishWithError(code: String, message: String, details: Any?) {
    NSLog("Native Entra sign-in failed with code %@", code)
    let result = flutterResult
    cleanUp()
    result?(FlutterError(code: code, message: message, details: details))
  }

  private func cleanUp() {
    timeoutWorkItem?.cancel()
    timeoutWorkItem = nil
    session = nil
    pending = nil
    flutterResult = nil
    processingCallback = false
  }

  private static func randomURLSafeString(byteCount: Int) -> String {
    var bytes = [UInt8](repeating: 0, count: byteCount)
    let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
    precondition(status == errSecSuccess)
    return base64URL(Data(bytes))
  }

  private static func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private static func formEncode(_ values: [String: String]) -> Data? {
    var components = URLComponents()
    components.queryItems = values.map { URLQueryItem(name: $0.key, value: $0.value) }
    return components.percentEncodedQuery?.data(using: .utf8)
  }
}

private struct PendingAuthorization {
  let clientID: String
  let redirectURI: String
  let redirectScheme: String
  let state: String
  let verifier: String
  let tokenURL: URL
  let scopes: [String]
}
