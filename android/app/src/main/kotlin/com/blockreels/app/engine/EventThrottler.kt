package com.blockreels.app.engine

import android.view.accessibility.AccessibilityEvent
import java.util.concurrent.ConcurrentHashMap

class EventThrottler(val debounceWindowMs: Long = 75L,
                     private val monotonicNowMs: () -> Long = { System.nanoTime() / 1_000_000L }) {
    private val lastEvaluationTimes = ConcurrentHashMap<String, Long>()

    /**
     * Determines whether an accessibility event should be evaluated based on type and timing.
     *
     * @param event The incoming AccessibilityEvent.
     * @param isOverlayActive Whether an intervention overlay is currently displayed.
     * @return true if the event should proceed to hierarchy traversal, false otherwise.
     */
    fun shouldProcess(event: AccessibilityEvent?, isOverlayActive: Boolean): Boolean {
        if (isOverlayActive || event == null) return false

        val packageName = event.packageName?.toString() ?: return false
        return shouldProcess(packageName, event.eventType, isOverlayActive, monotonicNowMs())
    }

    /**
     * Overload for testing without an Android AccessibilityEvent instance.
     */
    fun shouldProcess(packageName: String, eventType: Int, isOverlayActive: Boolean, timestamp: Long = monotonicNowMs()): Boolean {
        if (isOverlayActive) return false

        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            lastEvaluationTimes[packageName] = timestamp
            return true
        }

        if (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED ||
            eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
            eventType == AccessibilityEvent.TYPE_VIEW_CLICKED ||
            eventType == AccessibilityEvent.TYPE_VIEW_SELECTED) {
            val lastTime = lastEvaluationTimes[packageName]
            if (lastTime == null || timestamp - lastTime >= debounceWindowMs) {
                lastEvaluationTimes[packageName] = timestamp
                return true
            }
            return false
        }

        return false
    }

    fun reset(packageName: String) {
        lastEvaluationTimes.remove(packageName)
    }

    fun resetAll() {
        lastEvaluationTimes.clear()
    }
}
