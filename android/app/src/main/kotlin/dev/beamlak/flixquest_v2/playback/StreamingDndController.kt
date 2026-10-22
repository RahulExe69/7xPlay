package dev.beamlak.flixquest_v2.playback

import android.app.AutomaticZenRule
import android.app.NotificationManager
import android.app.UiModeManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import android.service.notification.Condition
import android.service.notification.ZenPolicy
import android.util.Log

/** Own a separate rule; never overwrite the user's global DND policy or other modes. */
class StreamingDndController(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)
    private val preferences = context.getSharedPreferences("streaming_dnd", Context.MODE_PRIVATE)
    private val sessions = mutableSetOf<Int>()
    private var foreground = false

    val supported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            context.getSystemService(UiModeManager::class.java)?.currentModeType !=
                Configuration.UI_MODE_TYPE_TELEVISION

    val accessGranted: Boolean
        get() = supported && manager.isNotificationPolicyAccessGranted

    init {
        // Recover our own rule after a process death, without turning off the user's DND.
        if (accessGranted) updateRule(false)
    }

    fun setSessionActive(id: Int, active: Boolean) {
        if (active) sessions.add(id) else sessions.remove(id)
        sync()
    }

    fun setForeground(value: Boolean) {
        foreground = value
        sync()
    }

    fun dispose() {
        sessions.clear()
        foreground = false
        sync()
    }

    private fun sync() {
        val active = foreground && sessions.isNotEmpty() && accessGranted
        StreamingDndConditionProvider.active = active
        // Always retry release on resume, including after access has been restored.
        updateRule(active)
    }

    private fun updateRule(active: Boolean) {
        if (!accessGranted) return
        try {
            var ruleId = preferences.getString(RULE_ID, null)
            if (ruleId != null && manager.getAutomaticZenRule(ruleId) == null) {
                preferences.edit().remove(RULE_ID).apply()
                ruleId = null
            }
            if (ruleId == null && active) {
                val policyBuilder = ZenPolicy.Builder()
                    .disallowAllSounds()
                    .allowMedia(true)
                    .allowAlarms(true)
                    .hideAllVisualEffects()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    policyBuilder.allowConversations(ZenPolicy.CONVERSATION_SENDERS_NONE)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.BAKLAVA) {
                    policyBuilder.allowPriorityChannels(false)
                }
                ruleId = manager.addAutomaticZenRule(
                    AutomaticZenRule(
                        "FlixQuest streaming",
                        ComponentName(context, StreamingDndConditionProvider::class.java),
                        null,
                        conditionId(context),
                        policyBuilder.build(),
                        NotificationManager.INTERRUPTION_FILTER_PRIORITY,
                        true,
                    ),
                )
                if (ruleId != null) preferences.edit().putString(RULE_ID, ruleId).commit()
            }
            if (ruleId != null) {
                manager.setAutomaticZenRuleState(ruleId, condition(context, active))
            }
        } catch (error: RuntimeException) {
            // Access can be revoked while a player is open. Never break playback.
            Log.w("StreamingDnd", "Unable to update streaming rule", error)
        }
    }

    companion object {
        private const val RULE_ID = "rule_id"

        fun conditionId(context: Context): Uri =
            Uri.parse("condition://${context.packageName}/streaming")

        fun condition(context: Context, active: Boolean) = Condition(
            conditionId(context),
            "FlixQuest streaming",
            if (active) Condition.STATE_TRUE else Condition.STATE_FALSE,
        )
    }
}
