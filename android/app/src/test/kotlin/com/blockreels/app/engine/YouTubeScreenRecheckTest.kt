package com.blockreels.app.engine

import android.view.accessibility.AccessibilityEvent
import com.blockreels.app.detection.YouTubeDetector
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.*
import org.junit.Test

class YouTubeScreenRecheckTest {
    private class Clock {
        var now = 0L
        val pending = mutableMapOf<Runnable, Long>()
        fun post(task: Runnable, delay: Long) { pending[task] = now + delay }
        fun remove(task: Runnable) { pending.remove(task) }
        fun next() {
            val entry = pending.minBy { it.value }
            now = entry.value
            pending.remove(entry.key)
            entry.key.run()
        }
    }

    @Test
    fun delayedConstructionAfterDiscardedContentEventGetsFreshViewerOnce() {
        // Synthetic timing fixture, not an observed YouTube device capture.
        val clock = Clock()
        val detector = YouTubeDetector()
        val throttler = EventThrottler()
        val pkg = "com.google.android.youtube"
        var currentRoot = syntheticTree(pkg)
        var matches = 0
        val recheck = ViewerScreenRecheck(clock::post, clock::remove) {
            val result = detector.evaluate(currentRoot)
            if (result.isMatch) matches++
            !result.isMatch
        }
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, false, 1000L))
        assertFalse(detector.evaluate(currentRoot).isMatch)
        recheck.request()
        // Viewer appears at t+30, but the final content event is throttled.
        currentRoot = syntheticTree(pkg, viewId = "$pkg:id/watch_while_layout") {
            node("$pkg:id/reel_recycler")
        }
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, false, 1030L))
        recheck.request()
        clock.next()
        assertEquals(150L, clock.now)
        assertEquals(1, matches)
        assertTrue(clock.pending.isEmpty())
    }

    @Test
    fun repeatedEventsDoNotPostponeChecksOrRenewTwoAttemptBudget() {
        val clock = Clock()
        var checks = 0
        val recheck = ViewerScreenRecheck(clock::post, clock::remove) { checks++; true }
        recheck.request()
        repeat(20) { clock.now++; recheck.request() }
        assertEquals(1, clock.pending.size)
        clock.next()
        assertEquals(150L, clock.now)
        repeat(20) { clock.now++; recheck.request() }
        clock.next()
        assertEquals(500L, clock.now)
        assertEquals(2, checks)
        assertTrue(clock.pending.isEmpty())
    }

    @Test
    fun viewerBuiltAfterFirstCheckIsFoundOnSecondCheck() {
        val clock = Clock()
        val detector = YouTubeDetector()
        var root = syntheticTree("com.google.android.youtube")
        var matches = 0
        val recheck = ViewerScreenRecheck(clock::post, clock::remove) {
            val matched = detector.evaluate(root).isMatch
            if (matched) matches++
            !matched
        }
        recheck.request()
        clock.next()
        root = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/reel_recycler")
        }
        clock.next()
        assertEquals(1, matches)
        assertTrue(clock.pending.isEmpty())
    }

    @Test
    fun cancellationRejectsStaleCallbacksAndFreshRequestsGetNewBudget() {
        val clock = Clock()
        var checks = 0
        val recheck = ViewerScreenRecheck(clock::post, clock::remove) { checks++; true }
        recheck.request()
        val stale = clock.pending.keys.single()
        recheck.cancel()
        recheck.request()
        stale.run()
        assertEquals(0, checks)
        clock.next()
        clock.next()
        assertEquals(2, checks)
        assertTrue(clock.pending.isEmpty())
    }

    @Test
    fun foregroundExitOrEligibilityStopDoesNotScheduleAnotherCheck() {
        val clock = Clock()
        var eligible = true
        var traversals = 0
        val recheck = ViewerScreenRecheck(clock::post, clock::remove) {
            if (!eligible) false else { traversals++; true }
        }
        recheck.request()
        eligible = false
        clock.next()
        assertEquals(0, traversals)
        assertTrue(clock.pending.isEmpty())
    }
}
