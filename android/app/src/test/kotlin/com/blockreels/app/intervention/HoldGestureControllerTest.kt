package com.blockreels.app.intervention

import android.view.MotionEvent
import org.junit.Assert.*
import org.junit.Test

class HoldGestureControllerTest {
    private class Fixture(val id: Long = 1L) {
        var now = 0L
        var ownerActive = true
        var parentLocked = false
        var completions = 0
        val parentRequests = mutableListOf<Boolean>()
        val pending = mutableMapOf<Runnable, Long>()
        val renders = mutableListOf<Triple<HoldGestureController.State, Int, Long>>()
        val order = mutableListOf<String>()
        val bounds = HoldGestureController.Bounds(0f, 0f, 200f, 100f)
        val gesture = HoldGestureController(id, 7, 8f, { now },
            { task, delay -> pending[task] = now + delay }, { pending.remove(it); Unit },
            { ownerActive },
            { parentLocked = it; parentRequests.add(it); order.add("parent:$it") },
            { state, progress, remaining ->
                renders.add(Triple(state, progress, remaining)); order.add("render:$state")
            }, { completions++ })

        fun touch(action: Int, pointer: Int = 1, x: Float? = 50f, y: Float? = 50f,
                  area: HoldGestureController.Bounds? = bounds): Boolean =
            gesture.onTouch(action, pointer, x, y, area)

        fun advanceTo(target: Long) {
            while (pending.isNotEmpty() && pending.values.min() <= target) {
                val entry = pending.minBy { it.value }
                now = entry.value
                pending.remove(entry.key)
                entry.key.run()
            }
            now = target
        }
    }

    @Test fun continuousSevenSecondHoldCompletesOnceAndRestoresParentScrolling() {
        val f = Fixture()
        assertTrue(f.touch(MotionEvent.ACTION_DOWN))
        assertEquals(listOf("parent:true", "render:PHYSICAL"), f.order)
        f.advanceTo(6999L)
        assertEquals(0, f.completions)
        assertEquals(1L, f.renders.last().third)
        f.advanceTo(7000L)
        assertEquals(1, f.completions)
        assertEquals(100, f.renders.last().second)
        assertEquals(listOf(true, false), f.parentRequests)
        assertTrue(f.pending.isEmpty())
        assertTrue(f.touch(MotionEvent.ACTION_UP))
        assertFalse(f.gesture.activateAccessibility())
        f.advanceTo(20000L)
        assertEquals(1, f.completions)
    }

    @Test fun pressInOffsetWindowDisplaysEverySecondOfTheHold() {
        val f = Fixture()
        val rawX = 650f
        val rawY = 1250f
        val area = HoldGestureController.Bounds.fromDown(rawX, rawY, 50f, 30f, 200, 60)
        f.touch(MotionEvent.ACTION_DOWN, x = rawX, y = rawY, area = area)
        for (second in 0..6) {
            f.advanceTo(second * 1000L)
            f.touch(MotionEvent.ACTION_MOVE, x = rawX + 1, y = rawY + 1)
            assertEquals(HoldGestureController.State.PHYSICAL, f.gesture.state)
            assertEquals(7L - second, f.renders.last().third)
            assertEquals(0, f.completions)
        }
        f.advanceTo(7000L)
        assertEquals(0L, f.renders.last().third)
        assertEquals(1, f.completions)
    }

    @Test fun quickTapAndReleaseCancelsAndCannotStartAnAccessibleTimer() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(100L)
        assertTrue(f.touch(MotionEvent.ACTION_UP))
        assertEquals(HoldGestureController.State.CANCELED, f.gesture.state)
        assertFalse(f.parentLocked)
        assertTrue(f.pending.isEmpty())
        f.advanceTo(10000L)
        assertEquals(0, f.completions)
    }

    @Test fun cancelAndRetryRequiresAFullNewSevenSecondsAndRejectsOldCallbacks() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(6000L)
        val old = f.pending.keys.single()
        assertTrue(f.touch(MotionEvent.ACTION_CANCEL))
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(7000L)
        old.run()
        assertEquals(0, f.completions)
        f.advanceTo(12999L)
        assertEquals(0, f.completions)
        f.advanceTo(13000L)
        assertEquals(1, f.completions)
    }

    @Test fun parentCannotInterceptTinyMovesWhileTheHoldOwnsTheGesture() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        // Simulate a scrolling parent's interception contract. A vertical drag
        // would deliver CANCEL unless the child disallowed interception.
        fun dispatchMove(y: Float) {
            if (!f.parentLocked && y > 58f) f.touch(MotionEvent.ACTION_CANCEL)
            else assertTrue(f.touch(MotionEvent.ACTION_MOVE, y = y))
        }
        dispatchMove(62f)
        f.advanceTo(3000L)
        dispatchMove(60f)
        f.advanceTo(7000L)
        assertEquals(1, f.completions)
        assertFalse(f.parentLocked)
    }

    @Test fun smallEdgeDriftIsToleratedButLeavingBeyondSlopCannotResumeOnMove() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN, x = 2f)
        assertTrue(f.touch(MotionEvent.ACTION_MOVE, x = -7f))
        assertEquals(HoldGestureController.State.PHYSICAL, f.gesture.state)
        f.advanceTo(3000L)
        f.touch(MotionEvent.ACTION_MOVE, x = -9f)
        assertTrue(f.parentLocked)
        f.touch(MotionEvent.ACTION_MOVE, x = 20f)
        f.touch(MotionEvent.ACTION_UP)
        assertFalse(f.parentLocked)
        f.advanceTo(10000L)
        assertEquals(0, f.completions)
        assertTrue(f.pending.isEmpty())
    }

    @Test fun secondPointerDoesNotRestartHoldOrTakeOwnershipWhenFirstLifts() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(3000L)
        assertTrue(f.touch(MotionEvent.ACTION_POINTER_DOWN, pointer = 2))
        assertEquals(1, f.gesture.activePointerId)
        assertTrue(f.touch(MotionEvent.ACTION_POINTER_UP, pointer = 2))
        f.advanceTo(7000L)
        assertEquals(1, f.completions)

        val g = Fixture()
        g.touch(MotionEvent.ACTION_DOWN)
        g.advanceTo(3000L)
        g.touch(MotionEvent.ACTION_POINTER_DOWN, pointer = 2)
        g.touch(MotionEvent.ACTION_POINTER_UP, pointer = 1)
        g.touch(MotionEvent.ACTION_MOVE, pointer = 2)
        g.advanceTo(10000L)
        assertEquals(0, g.completions)
        assertTrue(g.pending.isEmpty())
        g.touch(MotionEvent.ACTION_UP, pointer = 2)
        g.touch(MotionEvent.ACTION_DOWN, pointer = 2)
        g.advanceTo(17000L)
        assertEquals(1, g.completions)

        val h = Fixture()
        h.touch(MotionEvent.ACTION_DOWN)
        h.advanceTo(3000L)
        h.touch(MotionEvent.ACTION_MOVE, x = null, y = null)
        h.advanceTo(10000L)
        assertEquals(0, h.completions)
        assertTrue(h.parentLocked)
        h.touch(MotionEvent.ACTION_CANCEL)
        assertFalse(h.parentLocked)
    }

    @Test fun entranceFadeAndLayoutReflowPreserveAnEdgePress() {
        val f = Fixture()
        // Begin while the alpha-only entrance is still running.
        f.advanceTo(75L)
        f.touch(MotionEvent.ACTION_DOWN, x = 2f, y = 98f)
        f.advanceTo(160L)
        f.touch(MotionEvent.ACTION_MOVE, x = -3f, y = 103f)
        f.advanceTo(2000L)
        // Raw finger position is unchanged; the view's new layout is elsewhere.
        val shifted = HoldGestureController.Bounds(300f, 400f, 500f, 500f)
        f.touch(MotionEvent.ACTION_MOVE, x = -3f, y = 103f, area = shifted)
        f.advanceTo(7074L)
        assertEquals(0, f.completions)
        f.advanceTo(7075L)
        assertEquals(1, f.completions)
    }

    @Test fun accessibilityActivationWaitsFullDurationAndSecondActivationCancels() {
        val f = Fixture()
        assertTrue(f.gesture.activateAccessibility())
        assertFalse(f.parentLocked)
        f.advanceTo(6000L)
        assertTrue(f.gesture.activateAccessibility())
        assertTrue(f.pending.isEmpty())
        f.advanceTo(7000L)
        assertEquals(0, f.completions)
        assertTrue(f.gesture.activateAccessibility())
        // An UP without a physical DOWN cannot toggle a TalkBack timer.
        f.touch(MotionEvent.ACTION_UP)
        f.advanceTo(13999L)
        assertEquals(0, f.completions)
        f.advanceTo(14000L)
        assertEquals(1, f.completions)
    }

    @Test fun accessibilityActionCannotSwitchModesDuringAPhysicalPress() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(3000L)
        assertFalse(f.gesture.activateAccessibility())
        assertEquals(HoldGestureController.State.PHYSICAL, f.gesture.state)
        f.advanceTo(7000L)
        assertEquals(1, f.completions)
    }

    @Test fun detachOrOwnerReplacementClosesTheGestureAndAllScheduledWork() {
        for (explicitClose in listOf(false, true)) {
            val old = Fixture(1L)
            old.touch(MotionEvent.ACTION_DOWN)
            old.advanceTo(6000L)
            val stale = old.pending.keys.single()
            if (explicitClose) old.gesture.close() else old.ownerActive = false
            old.advanceTo(7000L)
            stale.run()
            assertEquals(0, old.completions)
            assertFalse(old.parentLocked)
            assertTrue(old.pending.isEmpty())
            assertEquals(HoldGestureController.State.CLOSED, old.gesture.state)
            val replacement = Fixture(2L)
            replacement.touch(MotionEvent.ACTION_DOWN)
            old.gesture.close()
            stale.run()
            replacement.advanceTo(7000L)
            assertEquals(1, replacement.completions)
        }
    }

    @Test fun disablingForExitCancelsHoldAndReenablingRequiresFullRetry() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(6000L)
        f.gesture.setEnabled(false)
        assertFalse(f.parentLocked)
        assertTrue(f.pending.isEmpty())
        assertFalse(f.gesture.activateAccessibility())
        f.touch(MotionEvent.ACTION_UP)
        f.advanceTo(7000L)
        f.gesture.setEnabled(true)
        f.touch(MotionEvent.ACTION_DOWN)
        f.advanceTo(13999L)
        assertEquals(0, f.completions)
        f.advanceTo(14000L)
        assertEquals(1, f.completions)
    }

    @Test fun lateMainThreadTickUsesElapsedTimeButCannotUnlockAfterCancellation() {
        val f = Fixture()
        f.touch(MotionEvent.ACTION_DOWN)
        val task = f.pending.keys.single()
        f.now = 7000L
        f.pending.remove(task)
        task.run()
        assertEquals(1, f.completions)
        assertEquals(2, f.renders.size) // Start and completion; not 140 counted ticks.
        assertTrue(f.pending.isEmpty())

        val g = Fixture()
        g.touch(MotionEvent.ACTION_DOWN)
        val late = g.pending.keys.single()
        g.now = 7000L
        g.touch(MotionEvent.ACTION_CANCEL)
        late.run()
        assertEquals(0, g.completions)
        assertTrue(g.pending.isEmpty())
    }
}
