package com.blockreels.app.engine

import android.view.accessibility.AccessibilityEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class EventThrottlerTest {

    @Test fun scrollOnlyTransitionsAreProcessedWithTheSameContentBudget() {
        val throttler = EventThrottler()
        val pkg = "com.zhiliaoapp.musically"
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_SCROLLED, false, 1000L))
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, false, 1020L))
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_SCROLLED, false, 1075L))
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_SCROLLED, true, 1200L))
    }

    @Test fun tabClicksAndPageSelectionsCanTriggerAnInAppScreenCheck() {
        val pkg = "com.google.android.youtube"
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_CLICKED, false, 1000L))
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_SELECTED, false, 1020L))
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_VIEW_SELECTED, false, 1075L))
    }

    private lateinit var throttler: EventThrottler

    @Before
    fun setUp() {
        throttler = EventThrottler(debounceWindowMs = 75L)
    }

    @Test
    fun testWindowStateChangedBypassesDebounceWithZeroLatency() {
        val pkg = "com.instagram.android"
        val now = 1000L

        // First window state change -> passes
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, isOverlayActive = false, timestamp = now))

        // Second window state change only 10ms later -> passes immediately (0ms delay)
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, isOverlayActive = false, timestamp = now + 10))
    }

    @Test
    fun testWindowContentChangedDebouncesWithin75ms() {
        val pkg = "com.google.android.youtube"
        val now = 1000L

        // First content change -> passes
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now))

        // Rapid scroll event 30ms later -> rejected
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 30))

        // Rapid scroll event 60ms later -> rejected
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 60))

        // Event 80ms later (>= 75ms) -> passes
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 80))
    }

    @Test
    fun testOverlayActiveRejectsAllEvents() {
        val pkg = "com.instagram.android"
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, isOverlayActive = true, timestamp = 1000L))
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = true, timestamp = 1000L))
    }

    @Test
    fun testIndependentPackageDebouncing() {
        val now = 1000L
        val ig = "com.instagram.android"
        val yt = "com.google.android.youtube"

        assertTrue(throttler.shouldProcess(ig, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now))
        // YouTube event 10ms later should still pass because it's a different package
        assertTrue(throttler.shouldProcess(yt, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 10))
    }

    @Test
    fun testResetClearsHistory() {
        val pkg = "com.facebook.katana"
        val now = 1000L

        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now))
        assertFalse(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 20))

        throttler.reset(pkg)

        // After reset, immediate event passes even within 20ms of previous
        assertTrue(throttler.shouldProcess(pkg, AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, isOverlayActive = false, timestamp = now + 20))
    }
}
