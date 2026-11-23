package com.blockreels.app.intervention

import com.blockreels.app.detection.YouTubeDetector
import com.blockreels.app.model.syntheticTree
import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import org.junit.Assert.*
import org.junit.Test

class OverlayResponsivenessTest {
    @Test fun pendingCoverDoesNotPausePlaybackBeforeItCanBeSeen() {
        val f = InterventionAudioCleanupTest.Fixture()
        f.overlay.attachOnShow = false
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.instagram.android")
        assertEquals("focus requested while cover is still queued", 0, f.client.requests)
        val cover = f.overlay.calls.single()
        f.overlay.isOverlayAttached = true
        cover.attached()
        assertEquals(1, f.client.requests)
        f.controller.dismissOverlay()
        cover.attached()
        assertEquals(1, f.client.requests)
    }

    @Test fun leaveDetachesBeforeBackAndDoesNotReopenFromTheOutgoingFrame() {
        for (pkg in listOf("com.instagram.android", "com.google.android.youtube")) {
            val f = InterventionAudioCleanupTest.Fixture()
            val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
            f.controller.executeIntervention(pkg, config, windowId = 7)
            val cover = f.overlay.calls.single()
            var coveredDuringBack = false
            f.onBack = { coveredDuringBack = f.overlay.isOverlayAttached }
            cover.exit()
            cover.exit()
            assertFalse("outgoing screen still covered during Back", coveredDuringBack)
            assertEquals(1, f.backs)
            assertFalse("old player frame immediately recreated cover",
                f.controller.executeIntervention(pkg, config, windowId = 7))
            assertFalse(f.controller.isAppTemporarilyAllowed(pkg))
            f.nowMs += 1000
            assertTrue("a player still open must be covered again",
                f.controller.executeIntervention(pkg, config, windowId = 7))
        }
    }

    @Test fun confirmedNavigationAllowsImmediateBlockingOnDeliberateReentry() {
        val f = InterventionAudioCleanupTest.Fixture()
        val pkg = "com.google.android.youtube"
        val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
        f.controller.executeIntervention(pkg, config)
        f.overlay.calls.single().exit()
        val comments = YouTubeDetector().evaluate(syntheticTree(pkg) { node("$pkg:id/comment_composer") })
        assertTrue(comments.foregroundSuppressionConfirmed)
        f.controller.onScreenEvaluated(pkg, comments)
        assertTrue(f.controller.executeIntervention(pkg, config))
    }
}
