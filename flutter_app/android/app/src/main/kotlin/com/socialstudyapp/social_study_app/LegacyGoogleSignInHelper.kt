package com.socialstudyapp.social_study_app

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import io.flutter.plugin.common.MethodChannel

/**
 * Native Google Sign-In using the classic Play Services API
 * (com.google.android.gms.auth.api.signin.GoogleSignIn).
 *
 * This completely bypasses the Credential Manager used by google_sign_in_android 7.x,
 * which causes code 10 (DEVELOPER_ERROR) and code 16 (account reauth failed) on
 * AAB Play Store builds with cross-client OAuth.
 *
 * The classic API uses GoogleSignInClient.startActivityForResult() — a proven,
 * stable mechanism that has worked since Android 5.0.
 */
class LegacyGoogleSignInHelper(
    private val activity: Activity,
    private val serverClientId: String,
) {
    companion object {
        const val GOOGLE_SIGN_IN_REQUEST_CODE = 9001
        const val CHANNEL = "com.socialstudyapp.app/google_sign_in"
    }

    private var pendingResult: MethodChannel.Result? = null

    private val gso: GoogleSignInOptions by lazy {
        GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(serverClientId)  // Gets id_token for the backend
            .requestEmail()
            .requestProfile()
            .build()
    }

    private val client by lazy { GoogleSignIn.getClient(activity, gso) }

    /** Called from MainActivity's MethodChannel handler. */
    fun signIn(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("SIGN_IN_ACTIVE", "A sign-in is already in progress.", null)
            return
        }
        pendingResult = result

        // Always sign out first to force a fresh account picker and fresh token.
        client.signOut().addOnCompleteListener {
            val signInIntent = client.signInIntent
            activity.startActivityForResult(signInIntent, GOOGLE_SIGN_IN_REQUEST_CODE)
        }
    }

    /** Called directly from MainActivity.onActivityResult(). */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != GOOGLE_SIGN_IN_REQUEST_CODE) return false

        val pending = pendingResult ?: return false
        pendingResult = null

        try {
            val task = GoogleSignIn.getSignedInAccountFromIntent(data)
            val account: GoogleSignInAccount = task.getResult(ApiException::class.java)
            val idToken = account.idToken
            if (idToken.isNullOrEmpty()) {
                pending.error("NO_ID_TOKEN", "Google sign in succeeded but no ID token was returned.", null)
            } else {
                pending.success(idToken)
            }
        } catch (e: ApiException) {
            if (e.statusCode == com.google.android.gms.common.api.CommonStatusCodes.CANCELED) {
                pending.error("CANCELED", "Google sign in was cancelled by the user.", null)
            } else {
                pending.error("SIGN_IN_FAILED", "Google sign in failed with status code: ${e.statusCode}", null)
            }
        }
        return true
    }
}
