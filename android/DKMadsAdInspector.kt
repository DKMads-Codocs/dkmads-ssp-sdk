package com.dkmads.ssp

import android.app.Activity
import android.util.Log

object DKMadsAdInspector {
    fun present(activity: Activity) {
        if (!SSPSDK.isDebugEnabled()) {
            Log.w("DKMads SSP", "Ad Inspector requires debug=true in SSPSDK.Config")
            return
        }
        DKMadsAdInspectorActivity.launch(activity)
    }
}
