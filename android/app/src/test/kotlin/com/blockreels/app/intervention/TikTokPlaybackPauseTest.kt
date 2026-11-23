package com.blockreels.app.intervention

import com.blockreels.app.engine.TraversalEngine
import com.blockreels.app.model.AccessibilityNode
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Test

class TikTokPlaybackPauseTest {
    private val pkg = "com.zhiliaoapp.musically"
    private val engine = TraversalEngine()
    private val buttonBounds = intArrayOf(480, 1100, 600, 1220)

    @Test fun explicitPauseWithinCurrentViewerIsClickedAtMostOnce() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/vertical_viewpager") {
                repeat(2) { node(packageName = pkg, bounds = buttonBounds) }
            }
        }
        var clicks = 0
        val result = TikTokPlaybackPause.attempt(tree, engine, { TikTokPlaybackPause.Control(true, "Pause video", null) }) {
            clicks++
            true
        }
        assertEquals(TikTokPlaybackPause.Outcome.CLICK_ACCEPTED, result)
        assertEquals(1, clicks)
    }

    @Test fun genericToggleRequiresPlayingStateAndNeverResumesPausedPlayback() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/viewpager") {
                node(contentDescription = "Play/Pause", packageName = pkg, isClickable = true, bounds = buttonBounds)
            }
        }
        for (state in listOf(null, "Paused", "Playing")) {
            var clicks = 0
            val result = TikTokPlaybackPause.attempt(tree, engine, { TikTokPlaybackPause.Control(true, null, state) }) {
                clicks++
                false
            }
            assertEquals(if (state == "Playing") TikTokPlaybackPause.Outcome.CLICK_REJECTED
                else TikTokPlaybackPause.Outcome.NO_CONTROL, result)
            assertEquals(if (state == "Playing") 1 else 0, clicks)
        }
    }

    @Test fun unrelatedHiddenOffscreenAndForeignPackageControlsAreIgnored() {
        val tree = syntheticTree(pkg) {
            node(packageName = pkg, bounds = buttonBounds) // Same screen, outside viewer.
            node("$pkg:id/viewpager", isVisibleToUser = false) {
                node(packageName = pkg, bounds = buttonBounds)
            }
            node("$pkg:id/main_feed_container") {
                node(packageName = "com.blockreels.app", bounds = buttonBounds)
                node(packageName = pkg, bounds = intArrayOf(480, 2500, 600, 2620))
            }
        }
        val result = TikTokPlaybackPause.attempt(tree, engine, { TikTokPlaybackPause.Control(true, "Pause", "Playing") }) {
            error("Only a verified control in the active viewer may be clicked")
        }
        assertEquals(TikTokPlaybackPause.Outcome.NO_CONTROL, result)
    }

    @Test fun refreshRejectsAToggleThatStoppedPlayingBeforeTheClick() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/viewpager") {
                node(contentDescription = "Play/Pause", packageName = pkg, isClickable = true, bounds = buttonBounds)
            }
        }
        var state = "Playing"
        val result = TikTokPlaybackPause.attempt(
            tree, engine,
            controlFor = { TikTokPlaybackPause.Control(true, null, state) },
            refresh = { state = "Paused"; true }
        ) { error("A paused toggle must never be clicked") }
        assertEquals(TikTokPlaybackPause.Outcome.CONTROL_CHANGED, result)
    }

    @Test fun unlabeledVideoAndCaptionDoNotBecomePauseActions() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/viewpager") {
                node(text = "Pause", className = "android.widget.TextView", packageName = pkg, isClickable = true)
                node(contentDescription = "Play video", className = "android.widget.Button",
                    packageName = pkg, isClickable = true, bounds = buttonBounds)
                node(packageName = pkg, isClickable = true, className = "android.view.SurfaceView")
            }
        }
        val read: (AccessibilityNode) -> TikTokPlaybackPause.Control = {
            TikTokPlaybackPause.Control(true, null, "Playing")
        }
        val result = TikTokPlaybackPause.attempt(tree, engine, read) { error("No explicit pause control") }
        assertEquals(TikTokPlaybackPause.Outcome.NO_CONTROL, result)
    }
}
