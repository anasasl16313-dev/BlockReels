package com.blockreels.app.bridge

import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import com.blockreels.app.state.NativeStateStore
import com.blockreels.app.state.ScheduleRule
import com.blockreels.app.state.TestPreferencesStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Calendar

class AccessibilityBridgePluginTest {

    @Test
    fun validatesEveryRuleBeforePassingAnythingToStorage() {
        val good = mapOf("packageName" to "example.app", "isEnabled" to true, "unused" to "ignored")
        val clean = validatedRecords(listOf(good), "rules").single()
        assertEquals("example.app", clean["packageName"])
        assertFalse(clean.containsKey("unused"))
        for (bad in listOf(
            good + ("isEnabled" to 1),
            good + ("packageName" to "invalid package"),
            good + ("interventionMode" to "unknown"),
            good + ("holdDurationSeconds" to Long.MAX_VALUE)
        )) {
            org.junit.Assert.assertThrows(IllegalArgumentException::class.java) {
                validatedRecords(listOf(bad), "rules")
            }
        }
        org.junit.Assert.assertThrows(IllegalArgumentException::class.java) {
            validatedRecords(listOf(good, good), "rules")
        }
    }

    @Before
    fun setUp() = runBlocking {
        NativeStateStore.resetForTests()
        NativeStateStore.initialize(TestPreferencesStore()).await()
        NativeStateStore.blockEventWriterForTests = { }
        NativeStateStore.resetMetrics()
        NativeStateStore.setMasterEnabledInMemory(true)
        NativeStateStore.setSchedulesInMemory(emptyList())
        NativeStateStore.setInterventionConfigInMemory(
            InterventionConfig(
                mode = InterventionMode.AUTO_BACK,
                holdDurationSeconds = 5,
                customMessage = "Take a breath",
                soundEnabled = false,
                hapticsEnabled = true,
                pinProtected = false
            )
        )
    }

    @Test
    fun testNativeStateStoreMetricsTracking() = runBlocking {
        NativeStateStore.recordBlockEvent("com.instagram.android", "CLIPS_VIEWER_MATCH").join()
        NativeStateStore.recordBlockEvent("com.instagram.android", "CLIPS_VIEWER_MATCH").join()
        NativeStateStore.recordBlockEvent("com.google.android.youtube", "REEL_RECYCLER_MATCH").join()

        val metrics = NativeStateStore.getMetricsSnapshot()
        assertEquals(3, metrics["totalBlockedToday"])
        assertEquals("com.google.android.youtube", metrics["lastBlockedPackage"])

        @Suppress("UNCHECKED_CAST")
        val byApp = metrics["byApp"] as Map<String, Int>
        assertEquals(2, byApp["com.instagram.android"])
        assertEquals(1, byApp["com.google.android.youtube"])
    }

    @Test
    fun testNativeStateStoreAppToggles() {
        NativeStateStore.setAppTogglesInMemory(
            mapOf(
                "com.instagram.android" to true,
                "com.facebook.katana" to false
            )
        )

        assertTrue(NativeStateStore.isAppBlockingActive("com.instagram.android"))
        assertFalse(NativeStateStore.isAppBlockingActive("com.facebook.katana"))
    }

    @Test
    fun testNativeStateStoreInterventionConfig() {
        NativeStateStore.setInterventionConfigInMemory(
            InterventionConfig(
                mode = InterventionMode.MINDFUL_PAUSE,
                holdDurationSeconds = 12,
                customMessage = "Be mindful of your attention.",
                soundEnabled = true,
                hapticsEnabled = false,
                pinProtected = true
            )
        )

        val config = NativeStateStore.getInterventionConfig()
        assertEquals(InterventionMode.MINDFUL_PAUSE, config.mode)
        assertEquals(12, config.holdDurationSeconds)
        assertEquals("Be mindful of your attention.", config.customMessage)
        assertTrue(config.soundEnabled)
        assertFalse(config.hapticsEnabled)
        assertTrue(config.pinProtected)
    }

    @Test
    fun testNativeStateStoreEventBroadcast() = runBlocking {
        var receivedEvent: Map<String, Any>? = null
        NativeStateStore.eventBroadcaster = { event ->
            receivedEvent = event
        }

        NativeStateStore.recordBlockEvent("com.instagram.android", "CLIPS_CONTAINER").join()

        assertNotNull(receivedEvent)
        assertEquals("REEL_BLOCKED", receivedEvent?.get("eventType"))
        assertEquals("com.instagram.android", receivedEvent?.get("packageName"))
        assertEquals("INSTAGRAM", receivedEvent?.get("appType"))
        assertEquals("CLIPS_CONTAINER", receivedEvent?.get("detectionReason"))
    }

    @Test
    fun testNativeStateStoreSchedulesInMemory() {
        val rule = ScheduleRule(
            id = "test_rule",
            title = "Night",
            isActive = true,
            daysOfWeek = setOf(1, 2, 3, 4, 5, 6, 7),
            startMinuteOfDay = 0,
            endMinuteOfDay = 1439,
            enabledPackages = setOf("com.instagram.android")
        )

        NativeStateStore.setSchedulesInMemory(listOf(rule))
        val list = NativeStateStore.getSchedules()
        assertEquals(1, list.size)
        assertEquals("test_rule", list[0].id)
    }

    @Test
    fun testActiveScheduleOverridesDisabledIndividualAppToggle() {
        NativeStateStore.setAppTogglesInMemory(
            mapOf("com.instagram.android" to false)
        )
        NativeStateStore.setSchedulesInMemory(
            listOf(activeScheduleForInstagram())
        )

        assertTrue(NativeStateStore.isAppBlockingActive("com.instagram.android"))
    }

    @Test
    fun testMasterSwitchStillDisablesAnActiveSchedule() {
        NativeStateStore.setAppTogglesInMemory(
            mapOf("com.instagram.android" to true)
        )
        NativeStateStore.setSchedulesInMemory(
            listOf(activeScheduleForInstagram())
        )
        NativeStateStore.setMasterEnabledInMemory(false)

        assertFalse(NativeStateStore.isAppBlockingActive("com.instagram.android"))
    }

    private fun activeScheduleForInstagram(): ScheduleRule {
        val calendar = Calendar.getInstance()
        val minute =
            calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
        val start = (minute + 1435) % 1440
        val end = (minute + 5) % 1440
        return ScheduleRule(
            id = "active_now",
            title = "Active now",
            isActive = true,
            daysOfWeek = setOf(1, 2, 3, 4, 5, 6, 7),
            startMinuteOfDay = start,
            endMinuteOfDay = end,
            enabledPackages = setOf("com.instagram.android")
        )
    }
}
