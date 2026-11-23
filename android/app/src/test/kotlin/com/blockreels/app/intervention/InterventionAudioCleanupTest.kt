package com.blockreels.app.intervention

import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import com.blockreels.app.detection.TikTokDetector
import com.blockreels.app.engine.ViewerScreenRecheck
import android.view.MotionEvent
import org.junit.Assert.*
import org.junit.Test

class InterventionAudioCleanupTest {
    @Test fun sevenSecondGestureGrantsTheExistingAllowanceOnceWithoutReplacingOverlay() {
        val f = Fixture()
        val pkg = "com.google.android.youtube"
        f.controller.executeIntervention(pkg,
            InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE, holdDurationSeconds = 7, soundEnabled = true))
        val call = f.overlay.calls.single()
        val pending = mutableMapOf<Runnable, Long>()
        var completed = 0
        val gesture = HoldGestureController(call.id, 7, 8f, { f.nowMs },
            { task, delay -> pending[task] = f.nowMs + delay }, { pending.remove(it); Unit },
            { f.controller.hasInterventionFor(pkg) }, {}, { _, _, _ -> }, {
                completed++
                call.unlock()
                f.overlay.dismiss(call.id)
            })
        gesture.onTouch(MotionEvent.ACTION_DOWN, 1, 50f, 50f,
            HoldGestureController.Bounds(0f, 0f, 200f, 100f))
        val stale = pending.keys.single()
        while (pending.isNotEmpty()) {
            val task = pending.minBy { it.value }
            f.nowMs = task.value
            if (f.nowMs in listOf(1500L, 4000L, 7000L)) {
                f.controller.onForegroundChanged(pkg, windowId = f.nowMs.toInt())
                assertFalse(f.controller.executeIntervention(pkg,
                    InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE, holdDurationSeconds = 7),
                    windowId = f.nowMs.toInt()))
            }
            pending.remove(task.key)
            task.key.run()
        }
        assertEquals(8000L, f.nowMs)
        assertEquals(1, completed)
        assertEquals(1, f.overlay.calls.size)
        assertEquals(1, f.overlay.dismissals.size)
        assertEquals(1, f.client.abandons)
        assertEquals(InterventionController.TEMPORARY_ALLOWANCE_MS,
            f.controller.temporaryAllowanceRemainingMs(pkg))
        f.nowMs += 1000L
        stale.run()
        call.unlock()
        gesture.onTouch(MotionEvent.ACTION_UP, 1, 50f, 50f)
        assertEquals(1, completed)
        assertEquals(InterventionController.TEMPORARY_ALLOWANCE_MS - 1000L,
            f.controller.temporaryAllowanceRemainingMs(pkg))
    }
    internal class FakeOverlay : InterventionOverlay {
        data class Call(
            val id: Long,
            val exit: () -> Unit,
            val unlock: () -> Unit,
            val dismissed: () -> Unit,
            val failed: () -> Unit,
            val attached: () -> Unit
        )
        val calls = mutableListOf<Call>()
        val dismissals = mutableListOf<Long>()
        val exitStates = mutableListOf<Pair<Long, OverlayExitState>>()
        var throwOnShow = false
        var onDismiss: () -> Unit = {}
        override var isOverlayAttached = false
        var attachOnShow = true
        var pending = false
        var activeId: Long? = null
        override fun isInterventionActive(interventionId: Long): Boolean =
            activeId == interventionId && (pending || isOverlayAttached)
        override fun setExitState(interventionId: Long, state: OverlayExitState) {
            if (activeId == interventionId) exitStates.add(interventionId to state)
        }

        override fun show(
            interventionId: Long, title: String, message: String, holdSeconds: Int,
            isStrictMode: Boolean, allowanceMinutes: Int, hapticsEnabled: Boolean,
            onExitRequested: () -> Unit, onUnlocked: () -> Unit,
            onDismissed: () -> Unit, onFailed: () -> Unit, onAttached: () -> Unit
        ) {
            if (throwOnShow) throw IllegalStateException("Injected overlay failure")
            calls += Call(interventionId, onExitRequested, onUnlocked, onDismissed, onFailed, onAttached)
            activeId = interventionId
            isOverlayAttached = attachOnShow
            pending = !attachOnShow
            if (attachOnShow) onAttached()
        }

        override fun dismiss(interventionId: Long) {
            // Completion is intentionally delayed so stale callbacks can be exercised.
            dismissals += interventionId
            if (activeId == interventionId) {
                activeId = null
                pending = false
                isOverlayAttached = false
            }
            onDismiss()
        }
    }

    internal class Fixture(focusGranted: Boolean = true,
                          onExitStarted: (Long) -> Unit = {}, onExitFinished: (Long) -> Unit = {},
                          onTikTokOverlayAttached: (String, Long) -> Unit = { _, _ -> },
                          mediaMute: OverlayMediaMute? = null) {
        val client = FakeAudioFocusClient().also { it.granted = focusGranted }
        val audio = AudioDuckingManager(client, mediaMute)
        val overlay = FakeOverlay()
        var backs = 0
        var homes = 0
        var onBack: () -> Unit = {}
        var nowMs = 1000L
        var homeAccepted = true
        var homeThrows = false
        val verifications = mutableListOf<Long>()
        val verificationEnds = mutableListOf<Long>()
        val controller = InterventionController(
            backLoopGuard = BackLoopGuard(debounceCooldownMs = 0L, clockMs = { nowMs }),
            audioDuckingManager = audio,
            onGlobalBackAction = { backs++; onBack(); true },
            onHomeAction = { homes++ },
            overlayManager = overlay,
            allowanceNowMs = { nowMs },
            onSystemHomeAction = {
                homes++
                if (homeThrows) throw IllegalStateException("Injected Home rejection")
                homeAccepted
            },
            onExitStarted = { verifications.add(it); onExitStarted(it) },
            onExitFinished = { verificationEnds.add(it); onExitFinished(it) },
            onTikTokOverlayAttached = onTikTokOverlayAttached
        )
        fun execute(mode: InterventionMode, packageName: String = "app.one", sound: Boolean = true) {
            controller.executeIntervention(packageName, InterventionConfig(mode = mode, soundEnabled = sound))
        }
    }

    @Test fun explicitTikTokLeaveUsesHomeInsteadOfRefreshingWithBack() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        f.overlay.calls.single().exit()
        assertEquals(0, f.backs)
        assertEquals(1, f.homes)
    }

    @Test fun allTikTokVariantsWaitForConfirmedApplicationExitAndCleanUpOnce() {
        for (pkg in TikTokDetector().targetPackages) for (granted in listOf(false, true)) {
            val f = Fixture(focusGranted = granted)
            f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
            val call = f.overlay.calls.single()
            call.exit()
            assertEquals(1, f.homes)
            assertEquals(0, f.backs)
            assertTrue(f.controller.isExitPending(call.id))
            assertEquals(granted, f.audio.hasAudioFocus)
            assertTrue(f.overlay.dismissals.isEmpty())
            call.unlock() // A canceled hold cannot grant an allowance while Exiting.
            assertFalse(f.controller.isAppTemporarilyAllowed(pkg))
            f.controller.onForegroundChanged(pkg, 99)
            f.controller.onForegroundChanged("com.ss.android.ugc.trill", 100)
            f.controller.onForegroundChanged("com.android.systemui", 101, isApplicationWindow = false)
            assertTrue(f.controller.isExitPending(call.id))
            f.controller.onForegroundChanged("launcher", 102)
            assertFalse(f.controller.hasInterventionFor(pkg))
            assertEquals(listOf(call.id), f.overlay.dismissals)
            assertEquals(1, f.client.abandons)
            assertEquals(listOf(call.id), f.verificationEnds)
            call.dismissed()
            call.failed()
            call.exit()
            f.controller.onExitVerificationTimeout(call.id)
            assertEquals(1, f.homes)
            assertEquals(1, f.client.abandons)
            assertFalse(f.controller.isAppTemporarilyAllowed(pkg))
        }
    }

    @Test fun rapidAndSlowRepeatedLeaveAttemptsDoNotRestartNavigationAfterGuardResets() {
        val f = Fixture()
        val pkg = "com.zhiliaoapp.musically"
        f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
        val call = f.overlay.calls.single()
        repeat(4) { call.exit() }
        repeat(4) {
            f.nowMs += 2000L // Longer than BackLoopGuard's 1200 ms reset.
            f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
            call.exit()
        }
        f.controller.onExitVerificationTimeout(call.id)
        repeat(4) { f.nowMs += 2000L; call.exit() }
        assertEquals(0, f.backs)
        assertEquals(1, f.homes)
        assertEquals(1, f.overlay.calls.size)
        assertEquals(listOf(OverlayExitState.EXITING, OverlayExitState.FAILED),
            f.overlay.exitStates.map { it.second })
        assertTrue(f.overlay.isOverlayAttached)
        assertTrue(f.audio.hasAudioFocus)
        call.unlock() // Failed exit still permits a legitimate full hold.
        call.dismissed()
        assertTrue(f.controller.isAppTemporarilyAllowed(pkg))
        assertEquals(1, f.client.abandons)
        assertEquals(listOf(call.id), f.verificationEnds)
    }

    @Test fun rejectedOrThrowingHomeRequestDoesNotFallBackToBackOrNavigationSpam() {
        for (throws in listOf(false, true)) {
            val f = Fixture()
            f.homeAccepted = false
            f.homeThrows = throws
            f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
            val call = f.overlay.calls.single()
            call.exit()
            assertFalse(f.controller.isExitPending(call.id))
            assertTrue(f.overlay.isOverlayAttached)
            assertTrue(f.audio.hasAudioFocus)
            assertEquals(OverlayExitState.FAILED, f.overlay.exitStates.last().second)
            call.exit()
            assertEquals(1, f.homes)
            assertEquals(0, f.backs)
            f.controller.onForegroundChanged("launcher", 8)
            assertEquals(1, f.client.abandons)
            assertEquals(listOf(call.id), f.overlay.dismissals)
            assertEquals(listOf(call.id), f.verificationEnds)
        }
    }

    @Test fun missingExitEvidenceGetsOnlyTwoChecksAndNeverClaimsExitOnAcceptance() {
        // Fake time proves scheduling bounds, not actual device navigation.
        var now = 0L
        val pending = mutableMapOf<Runnable, Long>()
        var id: Long? = null
        lateinit var f: Fixture
        lateinit var check: ViewerScreenRecheck
        check = ViewerScreenRecheck({ task, delay -> pending[task] = now + delay },
            { pending.remove(it); Unit }, 250L, 750L) {
            val current = id!!
            if (check.isFinalAttempt) {
                f.controller.onExitVerificationTimeout(current)
                false
            } else f.controller.isExitPending(current)
        }
        f = Fixture(onExitStarted = { id = it; check.request() },
            onExitFinished = { check.cancel() })
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        val call = f.overlay.calls.single()
        call.exit()
        var checks = 0
        while (pending.isNotEmpty()) {
            val next = pending.minBy { it.value }
            now = next.value
            pending.remove(next.key)
            next.key.run()
            checks++
        }
        assertEquals(2, checks)
        assertEquals(1000L, now)
        assertEquals(1, f.homes)
        assertFalse(f.controller.isExitPending(call.id))
        assertTrue(f.controller.hasInterventionFor("com.zhiliaoapp.musically"))
        assertEquals(OverlayExitState.FAILED, f.overlay.exitStates.last().second)
        f.controller.dismissOverlay()
        assertEquals(1, f.client.abandons)
    }

    @Test fun staleExitCallbacksCannotReleaseOrUnlockANewerIntervention() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        val old = f.overlay.calls.single()
        old.exit()
        f.controller.onForegroundChanged("launcher", 7)
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        val current = f.overlay.calls.last()
        current.exit()
        old.exit()
        old.unlock()
        old.failed()
        old.dismissed()
        f.controller.onExitVerificationTimeout(old.id)
        assertTrue(f.controller.isExitPending(current.id))
        assertTrue(f.audio.hasAudioFocus)
        assertEquals(2, f.homes)
        assertEquals(1, f.client.abandons)
        assertFalse(f.controller.isAppTemporarilyAllowed("com.zhiliaoapp.musically"))
        f.controller.onForegroundChanged("launcher", 8)
        assertEquals(2, f.client.abandons)
    }

    @Test fun focusLossWhileOverlayRemainsDoesNotDismissItOrReleaseTheWrongOwner() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        val call = f.overlay.calls.single()
        f.controller.onForegroundChanged("com.android.systemui", 30, isApplicationWindow = false)
        assertTrue(f.audio.hasAudioFocus)
        assertTrue(f.overlay.dismissals.isEmpty())
        f.client.callbacks.single()(FocusChange.LOSS_PERMANENT)
        assertFalse(f.audio.hasAudioFocus)
        assertTrue(f.overlay.isOverlayAttached)
        assertTrue(f.controller.hasInterventionFor("com.zhiliaoapp.musically"))
        assertEquals(0, f.client.abandons)
        call.exit()
        assertEquals(0, f.client.abandons)
        f.controller.onForegroundChanged("launcher", 8)
        assertEquals(1, f.client.abandons)
    }

    @Test fun repeatedSameContextKeepsExistingIntervention() {
        val f = Fixture()
        repeat(10) { f.execute(InterventionMode.MINDFUL_PAUSE, "com.instagram.android") }
        assertEquals(1, f.overlay.calls.size)
        assertEquals(1, f.client.requests)
        assertTrue(f.overlay.dismissals.isEmpty())
    }

    @Test fun pendingSameContextIsNotRequeuedBeforeAttachment() {
        val f = Fixture()
        f.overlay.attachOnShow = false
        repeat(10) { f.execute(InterventionMode.MINDFUL_PAUSE, "com.instagram.android") }
        assertEquals(1, f.overlay.calls.size)
        assertTrue(f.overlay.pending)
        assertFalse(f.controller.isOverlayActive())
    }

    @Test fun repeatedLeaveAndReopenClearsOldHoldEvenWhenWindowIdIsReused() {
        val f = Fixture()
        val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
        repeat(8) {
            assertTrue(f.controller.executeIntervention("com.instagram.android", config, windowId = 7))
            assertFalse(f.controller.executeIntervention("com.instagram.android", config, windowId = 7))
            f.controller.onForegroundChanged("launcher", 8)
            assertFalse(f.controller.hasInterventionFor("com.instagram.android"))
            assertFalse(f.audio.hasAudioFocus)
        }
        assertEquals(8, f.overlay.calls.size)
        assertEquals(8, f.overlay.dismissals.size)
    }

    @Test fun instagramWindowRefreshKeepsQueuedHoldUntilConfirmedAppExit() {
        val f = Fixture()
        f.overlay.attachOnShow = false
        val pkg = "com.instagram.android"
        val config = InterventionConfig(mode = InterventionMode.MINDFUL_PAUSE)
        f.controller.executeIntervention(pkg, config, windowId = 1)
        val old = f.overlay.calls.single()
        f.controller.onForegroundChanged(pkg, 2)
        assertFalse(f.controller.executeIntervention(pkg, config, windowId = 2))
        assertTrue(f.overlay.pending)
        assertTrue(f.overlay.dismissals.isEmpty())
        f.controller.onForegroundChanged("launcher", 3)
        assertEquals(listOf(old.id), f.overlay.dismissals)
        f.controller.executeIntervention(pkg, config, windowId = 2)
        old.failed()
        old.dismissed()
        old.unlock()
        assertFalse(f.controller.isAppTemporarilyAllowed(pkg))
        assertTrue(f.controller.hasInterventionFor(pkg))
        assertFalse(f.controller.executeIntervention(pkg, config, windowId = 2))
        assertEquals(2, f.overlay.calls.size)
    }

    @Test fun lostOverlayWithoutDismissCallbackDoesNotLeaveControllerStuck() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.instagram.android")
        f.overlay.isOverlayAttached = false
        f.overlay.pending = false
        f.execute(InterventionMode.MINDFUL_PAUSE, "com.instagram.android")
        assertEquals(2, f.overlay.calls.size)
        assertEquals(1, f.overlay.dismissals.size)
        assertTrue(f.audio.hasAudioFocus)
    }

    @Test fun activeAllowanceCancelsQueuedHoldAndExpiresWithoutBypassingItsDuration() {
        val f = Fixture()
        val pkg = "com.instagram.android"
        f.overlay.attachOnShow = false
        f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
        val old = f.overlay.calls.single()
        f.controller.grantTemporaryAllowance(pkg, 1000L)
        old.dismissed()
        assertFalse(f.overlay.pending)
        assertFalse(f.audio.hasAudioFocus)
        f.controller.onForegroundChanged("launcher", 8)
        f.nowMs += 999L
        f.controller.onForegroundChanged(pkg, 7)
        assertEquals(1L, f.controller.temporaryAllowanceRemainingMs(pkg))
        f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
        assertEquals(1, f.overlay.calls.size)
        f.nowMs++
        assertFalse(f.controller.isAppTemporarilyAllowed(pkg))
        f.execute(InterventionMode.MINDFUL_PAUSE, pkg)
        assertEquals(2, f.overlay.calls.size)
    }

    @Test fun autoBackReleasesGrantedFocusAndDenialDoesNotSkipBack() {
        for (granted in listOf(true, false)) {
            val f = Fixture(granted)
            f.execute(InterventionMode.AUTO_BACK)
            assertEquals(1, f.backs)
            assertFalse(f.audio.hasAudioFocus)
            assertFalse(f.client.hasRequest)
            assertEquals(1, f.client.abandons)
        }
    }

    @Test fun autoBackExceptionAlsoReleasesItsFocus() {
        val f = Fixture()
        f.onBack = { throw IllegalStateException("Injected back failure") }
        try {
            f.execute(InterventionMode.AUTO_BACK)
            fail("Expected injected navigation failure")
        } catch (_: IllegalStateException) { }
        assertFalse(f.audio.hasAudioFocus)
        assertFalse(f.client.hasRequest)
    }

    @Test fun overlayFailureAndMissingOverlayReleaseFocusAndStillBlock() {
        for (failure in listOf("callback", "throw", "missing")) {
            val f = Fixture()
            f.overlay.throwOnShow = failure == "throw"
            if (failure == "missing") f.controller.overlayManager = null
            f.execute(InterventionMode.MINDFUL_PAUSE)
            if (failure == "callback") f.overlay.calls.single().failed()
            assertEquals(1, f.backs)
            assertFalse(f.audio.hasAudioFocus)
            assertFalse(f.controller.isAppTemporarilyAllowed("app.one"))
        }
    }

    @Test fun deniedFocusStillShowsBothOverlayModesAndCleansUp() {
        for (mode in listOf(InterventionMode.MINDFUL_PAUSE, InterventionMode.STRICT_BLOCK)) {
            val f = Fixture(focusGranted = false)
            f.execute(mode)
            assertEquals(1, f.overlay.calls.size)
            assertFalse(f.audio.hasAudioFocus)
            assertFalse(f.client.hasRequest)
            assertEquals(if (mode == InterventionMode.STRICT_BLOCK) 1 else 0, f.backs)
            f.overlay.calls.single().dismissed()
            assertFalse(f.audio.hasAudioFocus)
            assertFalse(f.client.hasRequest)
        }
    }

    @Test fun exitDismissalAndServiceCleanupReleaseOverlayFocusWithoutUnlocking() {
        for (mode in listOf(InterventionMode.MINDFUL_PAUSE, InterventionMode.STRICT_BLOCK)) {
            for (cleanup in listOf("exit", "dismiss", "service")) {
                val f = Fixture()
                f.execute(mode)
                assertTrue(f.audio.hasAudioFocus)
                val call = f.overlay.calls.single()
                when (cleanup) {
                    "exit" -> call.exit()
                    "dismiss" -> call.dismissed()
                    else -> f.controller.dismissOverlay()
                }
                assertFalse(f.audio.hasAudioFocus)
                assertFalse(f.client.hasRequest)
                assertFalse(f.controller.isAppTemporarilyAllowed("app.one"))
                if (cleanup == "service") assertEquals(listOf(call.id), f.overlay.dismissals)
            }
        }
    }

    @Test fun successfulHoldReleasesFocusAndPreservesTemporaryUnlock() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE)
        val call = f.overlay.calls.single()
        call.unlock()
        call.dismissed()
        assertFalse(f.audio.hasAudioFocus)
        assertTrue(f.controller.isAppTemporarilyAllowed("app.one"))
        f.execute(InterventionMode.MINDFUL_PAUSE)
        assertEquals(1, f.overlay.calls.size)
        assertEquals(1, f.client.requests)
    }

    @Test fun staleOverlayCallbacksCannotReleaseOrUnlockANewerIntervention() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE)
        val old = f.overlay.calls.single()
        f.execute(InterventionMode.MINDFUL_PAUSE, "app.two")
        old.dismissed()
        old.failed()
        old.exit()
        old.unlock()
        assertTrue(f.audio.hasAudioFocus)
        assertEquals(0, f.backs)
        assertFalse(f.controller.isAppTemporarilyAllowed("app.one"))
        assertFalse(f.controller.isAppTemporarilyAllowed("app.two"))
        f.overlay.calls.last().unlock()
        assertFalse(f.audio.hasAudioFocus)
        assertTrue(f.controller.isAppTemporarilyAllowed("app.two"))
    }

    @Test fun olderAutoBackCompletionCannotReleaseNewOverlayFocus() {
        val f = Fixture()
        f.onBack = { f.execute(InterventionMode.MINDFUL_PAUSE, "app.two") }
        f.execute(InterventionMode.AUTO_BACK)
        assertTrue(f.audio.hasAudioFocus)
        assertTrue(f.client.hasRequest)
        f.overlay.calls.single().dismissed()
        assertFalse(f.audio.hasAudioFocus)
    }

    @Test fun olderServiceCleanupCannotReleaseAnInterventionStartedDuringDismissal() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE)
        f.overlay.onDismiss = {
            f.overlay.onDismiss = {}
            f.execute(InterventionMode.MINDFUL_PAUSE, "app.two")
        }
        f.controller.dismissOverlay()
        assertTrue(f.audio.hasAudioFocus)
        assertTrue(f.client.hasRequest)
        f.overlay.calls.last().dismissed()
        assertFalse(f.audio.hasAudioFocus)
    }

    @Test fun aNewSoundDisabledInterventionReleasesThePreviousFocus() {
        val f = Fixture()
        f.execute(InterventionMode.MINDFUL_PAUSE)
        f.execute(InterventionMode.MINDFUL_PAUSE, "app.two", sound = false)
        assertEquals(1, f.client.requests)
        assertFalse(f.audio.hasAudioFocus)
        f.overlay.calls.first().dismissed()
        assertFalse(f.controller.isAppTemporarilyAllowed("app.two"))
    }
}
