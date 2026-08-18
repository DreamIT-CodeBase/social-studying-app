package com.socialstudyapp.social_study_app

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import io.flutter.plugin.common.MethodChannel

/**
 * Native Google Sign-In using the classic Play Services API
 * (com.google.android.gms.auth.api.signin.GoogleSignIn).
 *
 * This completely bypasses the Credential Manager used by google_sign_in_android 7.x,
 * which causes code 16 (account reauth failed) on Android.
 *
 * Uses GoogleSignInClient.startActivityForResult() with explicit Web Client ID.
 */
class LegacyGoogleSignInHelper(
    private val activity: Activity,
    private val defaultServerClientId: String,
) {
    companion object {
        const val GOOGLE_SIGN_IN_REQUEST_CODE = 9001
        const val CHANNEL = "com.socialstudyapp.app/google_sign_in"
    }

    private var pendingResult: MethodChannel.Result? = null

    /** Called from MainActivity's MethodChannel handler. */
    fun signIn(serverClientIdOverride: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("SIGN_IN_ACTIVE", "A sign-in is already in progress.", null)
            return
        }
        pendingResult = result

        val clientId = serverClientIdOverride?.takeIf { it.isNotBlank() } ?: defaultServerClientId

        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(clientId)  // Gets id_token for the backend
            .requestEmail()
            .requestProfile()
            .build()

        val client = GoogleSignIn.getClient(activity, gso)

        // Sign out first to ensure the account picker shows and a fresh token is minted
        client.signOut().addOnCompleteListener {
            try {
                val signInIntent = client.signInIntent
                activity.startActivityForResult(signInIntent, GOOGLE_SIGN_IN_REQUEST_CODE)
            } catch (e: Exception) {
                pendingResult = null
                result.error("INTENT_FAILED", "Failed to start Google sign in intent: ${e.message}", null)
            }
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
            val statusString = CommonStatusCodes.getStatusCodeString(e.statusCode)
            if (e.statusCode == CommonStatusCodes.CANCELED) {
                pending.error("CANCELED", "Google sign in was cancelled by the user.", null)
            } else {
                pending.error(
                    "SIGN_IN_FAILED",
                    "Google sign in failed with status code: ${e.statusCode} ($statusString). Package: ${activity.packageName}",
                    null,
                )
            }
        }
        return true
    }
}
