package com.blockreels.app.intervention

import org.junit.Assert.*
import org.junit.Test

class HoldTimerTest {
    @Test fun activationAlwaysWaitsForTheConfiguredDuration() {
        for (seconds in listOf(5, 8, 30)) {
            val timer = HoldTimer(seconds)
            timer.start(100L)
            assertFalse(timer.complete(100L))
            assertFalse(timer.complete(100L + seconds * 1000L - 1L))
            assertTrue(timer.complete(100L + seconds * 1000L))
            assertFalse(timer.complete(100L + seconds * 1000L))
        }
    }

    @Test fun cancelAndRestartRequiresAnotherFullDuration() {
        val timer = HoldTimer(8)
        timer.start(100L)
        timer.cancel()
        assertFalse(timer.complete(8100L))
        timer.start(9000L)
        assertFalse(timer.complete(16999L))
        assertTrue(timer.complete(17000L))
    }

    @Test fun progressAndRemainingUseTheSameClock() {
        val timer = HoldTimer(8)
        timer.start(100L)
        assertEquals(50, timer.progress(4100L))
        assertEquals(4L, timer.remainingSeconds(4100L))
        assertEquals(1L, timer.remainingSeconds(8099L))
        assertEquals(100, timer.progress(8100L))
        assertEquals(0L, timer.remainingSeconds(8100L))
    }
}
