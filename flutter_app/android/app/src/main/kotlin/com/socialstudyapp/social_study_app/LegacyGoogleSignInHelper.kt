package com.socialstudyapp.social_study_app

import android.app.Activity
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import io.flutter.plugin.common.MethodChannel

class LegacyGoogleSignInHelper(
    private val activity: Activity,
    private val defaultServerClientId: String,
) {
    companion object {
        private const val REQUEST_CODE = 9001
        const val CHANNEL = "com.socialstudyapp.app/google_sign_in"
    }

    private var pendingResult: MethodChannel.Result? = null

    fun signIn(serverClientIdOverride: String?, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("SIGN_IN_ACTIVE", "A Google sign-in is already active.", null)
            return
        }
        pendingResult = result

        val serverClientId = serverClientIdOverride
            ?.takeIf { it.isNotBlank() }
            ?: defaultServerClientId
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(serverClientId)
            .requestEmail()
            .requestProfile()
            .build()
        val client = GoogleSignIn.getClient(activity, options)

        client.signOut().addOnCompleteListener {
            try {
                activity.startActivityForResult(client.signInIntent, REQUEST_CODE)
            } catch (error: Exception) {
                pendingResult = null
                result.error(
                    "INTENT_FAILED",
                    "Could not open Google sign-in: ${error.message}",
                    null,
                )
            }
        }
    }

    fun onActivityResult(requestCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingResult ?: return false
        pendingResult = null

        try {
            val account = GoogleSignIn.getSignedInAccountFromIntent(data)
                .getResult(ApiException::class.java)
            val idToken = account.idToken
            if (idToken.isNullOrEmpty()) {
                result.error("NO_ID_TOKEN", "Google returned no ID token.", null)
            } else {
                result.success(idToken)
            }
        } catch (error: ApiException) {
            if (error.statusCode == CommonStatusCodes.CANCELED) {
                result.error("CANCELED", "Google sign-in was cancelled.", null)
            } else {
                result.error(
                    "SIGN_IN_FAILED",
                    "Google sign-in failed (${error.statusCode}: ${CommonStatusCodes.getStatusCodeString(error.statusCode)}).",
                    null,
                )
            }
        }
        return true
    }
}
