package com.blockreels.app.engine

import android.view.accessibility.AccessibilityEvent
import com.blockreels.app.detection.InstagramDetector
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.*
import org.junit.Test

class InstagramScreenRecheckTest {
    private class Queue {
        var now = 1000L
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

    @Test fun discardedEarlyContentEventStillGetsLatestReelsHierarchy() {
        // Synthetic construction/arrival timing, not measured device latency.
        val q = Queue()
        val detector = InstagramDetector()
        val pkg = "com.instagram.android"
        var root = syntheticTree(pkg)
        var matches = 0
        val recheck = ViewerScreenRecheck(q::post, q::remove, 75L, 150L) {
            val matched = detector.evaluate(root).isMatch
            if (matched) matches++
            !matched
        }
        val throttler = EventThrottler(monotonicNowMs = { q.now })
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, false))
        assertFalse(detector.evaluate(root).isMatch)
        recheck.request()
        q.now += 20L
        root = syntheticTree(pkg) {
            node("$pkg:id/clips_author_container", bounds = intArrayOf(24, 1880, 600, 1960))
            node("$pkg:id/clips_action_button", bounds = intArrayOf(920, 1400, 1060, 1540))
        }
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, false))
        recheck.request()
        q.next()
        assertEquals(1075L, q.now)
        assertEquals(1, matches)
        assertTrue(q.pending.isEmpty())
    }

    @Test fun leavingCancelsOldCallbacksAndReopeningReceivesItsOwnBoundedBudget() {
        val q = Queue()
        var checks = 0
        val recheck = ViewerScreenRecheck(q::post, q::remove, 75L, 150L) { checks++; true }
        recheck.request()
        val old = q.pending.keys.single()
        recheck.cancel()
        recheck.request()
        old.run()
        assertEquals(0, checks)
        q.next()
        assertTrue(recheck.isFinalAttempt)
        q.next()
        assertEquals(1225L, q.now)
        assertEquals(2, checks)
        assertTrue(q.pending.isEmpty())
    }
}
