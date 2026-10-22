package dev.beamlak.flixquest_v2.playback

import android.net.Uri
import android.service.notification.ConditionProviderService

/** The system rechecks this condition when reconnecting, including after a process restart. */
class StreamingDndConditionProvider : ConditionProviderService() {
    override fun onConnected() {
        notifyCondition(StreamingDndController.condition(this, active))
    }

    override fun onSubscribe(conditionId: Uri) {
        if (conditionId == StreamingDndController.conditionId(this)) {
            notifyCondition(StreamingDndController.condition(this, active))
        }
    }

    override fun onUnsubscribe(conditionId: Uri) = Unit

    companion object {
        // Deliberately process-local: a restarted process must never resume suppression itself.
        var active = false
    }
}
