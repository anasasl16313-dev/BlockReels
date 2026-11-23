package com.blockreels.app.intervention

import com.blockreels.app.detection.InstagramDetector
import com.blockreels.app.detection.DetectorRegistry
import com.blockreels.app.model.syntheticTree
import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class InterventionControllerTest {

    private lateinit var loopGuard: BackLoopGuard

    @Before
    fun setUp() {
        loopGuard = BackLoopGuard(maxRetries = 2, timeWindowMs = 1200L, debounceCooldownMs = 350L)
    }

    @Test
    fun instagramRechecksKeepAttachedHoldUntilForegroundScreenIsConfirmed() {
        val pkg = "com.instagram.android"
        val fixture = InterventionAudioCleanupTest.Fixture()
        val controller = fixture.controller
        val detector = InstagramDetector()
        val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
        assertTrue(controller.executeIntervention(pkg, config, windowId = 7))

        val blank = syntheticTree(pkg)
        val sharedHeader = syntheticTree(pkg) { node("$pkg:id/profile_header_container") }
        val retainedFeed = syntheticTree(pkg) {
            node("$pkg:id/feed_recycler_view", bounds = intArrayOf(0, 0, 1080, 900))
        }
        val editor = syntheticTree(pkg) {
            node(className = "android.widget.EditText", isEditable = true, isFocused = true)
        }
        for (root in listOf(blank, sharedHeader, retainedFeed, editor, blank)) {
            controller.onInstagramScreenEvaluated(detector.evaluate(root))
            assertTrue(fixture.overlay.isOverlayAttached)
        }
        controller.onForegroundChanged("com.android.systemui", 9, isApplicationWindow = false)
        controller.onForegroundChanged(pkg, 8)
        assertFalse(controller.executeIntervention(pkg, config, windowId = 8))
        assertEquals(1, fixture.overlay.calls.size)
        assertTrue(fixture.overlay.dismissals.isEmpty())

        val inbox = syntheticTree(pkg) { node("$pkg:id/direct_inbox_recycler_view") }
        controller.onInstagramScreenEvaluated(detector.evaluate(inbox))
        assertFalse(fixture.overlay.isOverlayAttached)
        assertFalse(controller.hasInterventionFor(pkg))
        assertFalse(controller.isAppTemporarilyAllowed(pkg))
    }

    @Test
    fun returningToAnAllowedSurfaceReleasesOnlyItsOwnAppsOverlay() {
        for ((pkg, safe) in listOf(
            "com.instagram.android" to "feed_recycler_view",
            "com.google.android.youtube" to "search_edit_text",
            "com.facebook.katana" to "news_feed_stream",
            "com.facebook.lite" to "messages_list_view",
            "com.zhiliaoapp.musically" to "profile_header"
        )) {
            val fixture = InterventionAudioCleanupTest.Fixture()
            val controller = fixture.controller
            val result = DetectorRegistry().getDetectorForPackage(pkg)!!.evaluate(
                syntheticTree(pkg) { node("$pkg:id/$safe") })
            assertTrue("$pkg must confirm the allowed screen", result.foregroundSuppressionConfirmed)
            controller.executeIntervention(pkg, InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE))
            controller.onScreenEvaluated("other.app", result)
            assertTrue(fixture.overlay.isOverlayAttached)
            controller.onScreenEvaluated(pkg, result)
            assertFalse("$pkg must not remain covered", fixture.overlay.isOverlayAttached)
            assertEquals(1, fixture.client.abandons)
            assertFalse(controller.isAppTemporarilyAllowed(pkg))
        }
    }

    @Test
    fun tiktokAttemptsPauseAfterAttachEvenWithDeniedFocusAndStillLeavesViaHome() {
        val pkg = "com.zhiliaoapp.musically"
        val pauses = mutableListOf<Pair<String, Long>>()
        val f = InterventionAudioCleanupTest.Fixture(focusGranted = false,
            onTikTokOverlayAttached = { packageName, id -> pauses += packageName to id })
        val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
        assertTrue(f.controller.executeIntervention(pkg, config, windowId = 7))
        val overlay = f.overlay.calls.single()
        assertEquals(listOf(pkg to overlay.id), pauses)
        assertEquals(AudioDuckingManager.FocusState.DENIED, f.audio.focusState)
        assertTrue(f.overlay.isOverlayAttached)
        f.controller.onForegroundChanged(pkg, 8)
        assertFalse(f.controller.executeIntervention(pkg, config, windowId = 8))
        assertEquals(1, f.client.requests)
        assertEquals(1, f.overlay.calls.size)

        overlay.exit()
        overlay.attached() // A delayed callback from the same overlay is now stale.
        assertEquals(1, pauses.size)
        assertEquals(1, f.homes)
        assertEquals(0, f.backs)
        assertTrue(f.controller.isExitPending(overlay.id))
        assertEquals(listOf(overlay.id to OverlayExitState.EXITING), f.overlay.exitStates)
        f.controller.onForegroundChanged("launcher", 9)
        assertFalse(f.controller.isExitPending(overlay.id))
        assertEquals(listOf(overlay.id), f.overlay.dismissals)
    }

    @Test
    fun tiktokSoundOptOutSkipsBothMitigations() {
        var attempts = 0
        val f = InterventionAudioCleanupTest.Fixture(
            onTikTokOverlayAttached = { _, _ -> attempts++ })
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically", sound = false)
        assertEquals(0, f.client.requests)
        assertEquals(0, attempts)
        assertTrue(f.overlay.isOverlayAttached)
    }

    @Test
    fun testBackLoopGuardFirstAttemptExecutesBack() {
        val decision = loopGuard.recordBackAttempt(now = 1000L)
        assertTrue("Expected ExecuteBack decision", decision is BackActionDecision.ExecuteBack)
        assertEquals(1, (decision as BackActionDecision.ExecuteBack).attempt)
    }

    @Test
    fun testBackLoopGuardSecondAttemptExecutesBack() {
        loopGuard.recordBackAttempt(now = 1000L)
        val decision = loopGuard.recordBackAttempt(now = 1400L) // +400ms > debounceCooldown (350ms)
        assertTrue(decision is BackActionDecision.ExecuteBack)
        assertEquals(2, (decision as BackActionDecision.ExecuteBack).attempt)
    }

    @Test
    fun testBackLoopGuardThirdAttemptFallsBackToHome() {
        loopGuard.recordBackAttempt(now = 1000L)
        loopGuard.recordBackAttempt(now = 1400L)
        val decision = loopGuard.recordBackAttempt(now = 1800L) // 3rd attempt within 1200ms window
        assertTrue("Exceeding maxRetries must trigger FallbackToHome", decision is BackActionDecision.FallbackToHome)
    }

    @Test
    fun testBackLoopGuardDebouncesRapidSpam() {
        loopGuard.recordBackAttempt(now = 1000L)
        val decision = loopGuard.recordBackAttempt(now = 1100L) // +100ms < debounceCooldown (350ms)
        assertTrue(decision is BackActionDecision.Debounced)
    }

    @Test
    fun testBackLoopGuardResetsAfterTimeWindowExpires() {
        loopGuard.recordBackAttempt(now = 1000L)
        loopGuard.recordBackAttempt(now = 1400L)

        // 2000ms later (> 1200ms window), window resets
        val decision = loopGuard.recordBackAttempt(now = 3500L)
        assertTrue(decision is BackActionDecision.ExecuteBack)
        assertEquals(1, (decision as BackActionDecision.ExecuteBack).attempt)
    }
}
