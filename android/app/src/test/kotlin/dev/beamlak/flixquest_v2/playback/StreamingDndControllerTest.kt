package dev.beamlak.flixquest_v2.playback

import android.app.Application
import android.app.NotificationManager
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import android.service.notification.Condition
import android.service.notification.ZenPolicy
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowNotificationManager

@RunWith(RobolectricTestRunner::class)
@Config(
    sdk = [29, 35], manifest = Config.NONE, application = Application::class,
    shadows = [StreamingDndControllerTest.RecordingNotificationManager::class],
)
class StreamingDndControllerTest {
    private val context: Context get() = RuntimeEnvironment.getApplication()
    private lateinit var manager: NotificationManager

    @Before fun setup() {
        manager = context.getSystemService(NotificationManager::class.java)
        shadowOf(manager).setNotificationPolicyAccessGranted(true)
        RecordingNotificationManager.states.clear()
        StreamingDndConditionProvider.active = false
        context.getSharedPreferences("streaming_dnd", Context.MODE_PRIVATE).edit().clear().commit()
    }

    @Test fun suppressesCallsAndVisualsWithoutMutingMediaOrAlarms() {
        val controller = StreamingDndController(context)
        controller.setForeground(true)
        controller.setSessionActive(1, true)
        val rule = manager.automaticZenRules.values.single()
        val policy = rule.zenPolicy!!
        assertEquals(NotificationManager.INTERRUPTION_FILTER_PRIORITY, rule.interruptionFilter)
        assertEquals(ZenPolicy.STATE_ALLOW, policy.priorityCategoryMedia)
        assertEquals(ZenPolicy.STATE_ALLOW, policy.priorityCategoryAlarms)
        assertEquals(ZenPolicy.STATE_DISALLOW, policy.priorityCategoryCalls)
        assertEquals(ZenPolicy.STATE_DISALLOW, policy.priorityCategoryRepeatCallers)
        assertEquals(ZenPolicy.STATE_DISALLOW, policy.priorityCategoryMessages)
        assertEquals(ZenPolicy.STATE_DISALLOW, policy.visualEffectPeek)
        assertEquals(ZenPolicy.STATE_DISALLOW, policy.visualEffectFullScreenIntent)
        assertEquals(Condition.STATE_TRUE, state())
    }

    @Test fun restoresOnBackgroundAndLastRouteExitWhileKeepingExistingDnd() {
        val originalPolicy = NotificationManager.Policy(
            NotificationManager.Policy.PRIORITY_CATEGORY_ALARMS, 0, 0,
        )
        manager.notificationPolicy = originalPolicy
        manager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALARMS)
        val controller = StreamingDndController(context)
        controller.setForeground(true)
        controller.setSessionActive(1, true)
        controller.setSessionActive(2, true)
        controller.setSessionActive(1, false)
        assertEquals(Condition.STATE_TRUE, state())
        controller.setForeground(false)
        assertEquals(Condition.STATE_FALSE, state())
        controller.setForeground(true)
        assertEquals(Condition.STATE_TRUE, state())
        controller.setSessionActive(2, false)
        assertEquals(Condition.STATE_FALSE, state())
        assertEquals(originalPolicy, manager.notificationPolicy)
        assertEquals(NotificationManager.INTERRUPTION_FILTER_ALARMS, manager.currentInterruptionFilter)
    }

    @Test fun noPermissionDoesNotCreateRuleAndGrantOnResumeAppliesIt() {
        shadowOf(manager).setNotificationPolicyAccessGranted(false)
        val controller = StreamingDndController(context)
        controller.setSessionActive(1, true)
        controller.setForeground(true)
        assertTrue(RecordingNotificationManager.states.isEmpty())
        shadowOf(manager).setNotificationPolicyAccessGranted(true)
        controller.setForeground(true)
        assertEquals(Condition.STATE_TRUE, state())
        controller.dispose()
        assertEquals(Condition.STATE_FALSE, state())
    }

    @Test fun processRestartReleasesStaleRuleAndReusesItOnNextPlayback() {
        val controller = StreamingDndController(context)
        controller.setForeground(true)
        controller.setSessionActive(1, true)
        val id = manager.automaticZenRules.keys.single()
        val restarted = StreamingDndController(context)
        assertEquals(Condition.STATE_FALSE, state())
        restarted.setForeground(true)
        restarted.setSessionActive(2, true)
        assertEquals(id, manager.automaticZenRules.keys.single())
        assertEquals(Condition.STATE_TRUE, state())
    }

    @Test fun revokedAccessIsSafeAndRemovedRuleIsNotRecreatedOnExit() {
        val controller = StreamingDndController(context)
        controller.setForeground(true)
        controller.setSessionActive(1, true)
        shadowOf(manager).setNotificationPolicyAccessGranted(false)
        controller.setSessionActive(1, false)
        assertFalse(StreamingDndConditionProvider.active)
        shadowOf(manager).setNotificationPolicyAccessGranted(true)
        controller.setForeground(true)
        // Android/Robolectric removes the app's rule on revocation. The old
        // recorded STATE_TRUE call is no longer associated with an existing rule.
        assertTrue(manager.automaticZenRules.isEmpty())
    }

    @Test fun televisionNeverActivatesSuppression() {
        shadowOf(context.getSystemService(UiModeManager::class.java))
            .setCurrentModeType(Configuration.UI_MODE_TYPE_TELEVISION)
        val controller = StreamingDndController(context)
        assertFalse(controller.supported)
        controller.setForeground(true)
        controller.setSessionActive(1, true)
        assertTrue(manager.automaticZenRules.isEmpty())
    }

    @Test @Config(sdk = [28]) fun olderAndroidIsUnsupported() {
        val controller = StreamingDndController(context)
        assertFalse(controller.supported)
        controller.setSessionActive(1, true)
        controller.setForeground(true)
        assertTrue(RecordingNotificationManager.states.isEmpty())
    }

    private fun state() = RecordingNotificationManager.states.values.single()

    // Robolectric models rules but not their condition updates; record the real API calls.
    @Implements(NotificationManager::class)
    class RecordingNotificationManager : ShadowNotificationManager() {
        @Implementation(minSdk = 29)
        fun setAutomaticZenRuleState(id: String, condition: Condition) {
            states[id] = condition.state
        }

        companion object {
            val states = mutableMapOf<String, Int>()
        }
    }
}
