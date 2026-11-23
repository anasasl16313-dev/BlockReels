package com.blockreels.app.intervention

import org.junit.Assert.*
import org.junit.Test

internal class FakeAudioFocusClient : AudioFocusClient {
    var granted = true
    var failRequest = false
    var failAbandon = false
    var requests = 0
    var abandons = 0
    var hasRequest = false
    val callbacks = mutableListOf<(FocusChange) -> Unit>()
    var initialChange: FocusChange? = null

    override fun requestFocus(interventionId: Long, onChange: (FocusChange) -> Unit): Boolean {
        requests++
        callbacks.add(onChange)
        hasRequest = true
        initialChange?.let(onChange)
        if (failRequest) throw IllegalStateException("Injected focus failure")
        return granted
    }

    override fun abandonFocus() {
        abandons++
        hasRequest = false
        if (failAbandon) throw IllegalStateException("Injected abandonment failure")
    }
}

class AudioDuckingManagerTest {
    @Test fun transientLossAndDuckingLossAreNotReportedAsHeldFocus() {
        for ((change, expected) in listOf(
            FocusChange.LOSS_TRANSIENT to AudioDuckingManager.FocusState.LOST_TRANSIENT,
            FocusChange.LOSS_CAN_DUCK to AudioDuckingManager.FocusState.LOST_CAN_DUCK)) {
            val client = FakeAudioFocusClient()
            val audio = AudioDuckingManager(client)
            audio.requestTransientFocus(1)
            client.callbacks.single()(change)
            assertFalse(audio.hasAudioFocus)
            assertEquals(expected, audio.focusState)
            assertTrue(client.hasRequest)
            assertFalse(audio.requestTransientFocus(1))
            assertEquals(1, client.requests)
            client.callbacks.single()(FocusChange.GAIN)
            assertTrue(audio.hasAudioFocus)
            audio.restoreAudio(1)
            assertEquals(1, client.abandons)
        }
    }

    @Test fun permanentLossDoesNotClaimRecoveryOrStartAFocusStealingLoop() {
        val client = FakeAudioFocusClient()
        val audio = AudioDuckingManager(client)
        audio.requestTransientFocus(1)
        client.callbacks.single()(FocusChange.LOSS_PERMANENT)
        client.callbacks.single()(FocusChange.GAIN)
        assertFalse(audio.hasAudioFocus)
        assertEquals(AudioDuckingManager.FocusState.LOST_PERMANENT, audio.focusState)
        assertFalse(audio.requestTransientFocus(1))
        assertEquals(1, client.requests)
        audio.restoreAudio(1)
        audio.restoreAudio(1)
        assertEquals(1, client.abandons)
    }

    @Test fun oldFocusCallbacksCannotChangeANewerOwnerOrARepeatedRequestId() {
        val client = FakeAudioFocusClient().apply { granted = false }
        val audio = AudioDuckingManager(client)
        audio.requestTransientFocus(1)
        client.granted = true
        audio.requestTransientFocus(1)
        client.callbacks[0](FocusChange.LOSS_PERMANENT)
        assertTrue(audio.hasAudioFocus)
        audio.requestTransientFocus(2)
        client.callbacks[1](FocusChange.LOSS_PERMANENT)
        assertTrue(audio.hasAudioFocus)
        client.callbacks[2](FocusChange.LOSS_TRANSIENT)
        client.callbacks[0](FocusChange.GAIN)
        assertFalse(audio.hasAudioFocus)
        audio.restoreAudio(1)
        assertTrue(client.hasRequest)
        audio.restoreAudio(2)
        client.callbacks[2](FocusChange.GAIN)
        assertFalse(audio.hasAudioFocus)
    }

    @Test fun synchronousLossIsNotOverwrittenBySuccessfulRequestReturn() {
        val client = FakeAudioFocusClient().apply { initialChange = FocusChange.LOSS_TRANSIENT }
        val audio = AudioDuckingManager(client)
        assertFalse(audio.requestTransientFocus(1))
        assertEquals(AudioDuckingManager.FocusState.LOST_TRANSIENT, audio.focusState)
        audio.restoreAudio(1)
        assertEquals(1, client.abandons)
    }
    @Test fun grantedFocusIsHeldUntilItsOwnerReleasesIt() {
        val client = FakeAudioFocusClient()
        val audio = AudioDuckingManager(client)
        assertTrue(audio.requestTransientFocus(1))
        assertTrue(audio.hasAudioFocus)
        assertTrue(audio.requestTransientFocus(1))
        assertEquals(1, client.requests)
        audio.restoreAudio(1)
        audio.restoreAudio(1)
        assertFalse(audio.hasAudioFocus)
        assertFalse(client.hasRequest)
        assertEquals(1, client.abandons)
    }

    @Test fun deniedAndThrownRequestsAreClearedAndCanBeRetried() {
        for (throws in listOf(false, true)) {
            val client = FakeAudioFocusClient().apply {
                granted = false
                failRequest = throws
            }
            val audio = AudioDuckingManager(client)
            assertFalse(audio.requestTransientFocus(1))
            assertFalse(audio.hasAudioFocus)
            assertEquals(if (throws) AudioDuckingManager.FocusState.REQUEST_ERROR
                else AudioDuckingManager.FocusState.DENIED, audio.focusState)
            assertFalse(client.hasRequest)
            assertEquals(1, client.abandons)
            client.granted = true
            client.failRequest = false
            assertTrue(audio.requestTransientFocus(2))
            assertTrue(audio.hasAudioFocus)
            audio.restoreAudio(2)
        }
    }

    @Test fun anOlderReleaseCannotAbandonANewerRequest() {
        val client = FakeAudioFocusClient()
        val audio = AudioDuckingManager(client)
        audio.requestTransientFocus(1)
        audio.requestTransientFocus(2)
        assertEquals(1, client.abandons)
        audio.restoreAudio(1)
        assertTrue(audio.hasAudioFocus)
        assertTrue(client.hasRequest)
        assertEquals(1, client.abandons)
        audio.restoreAudio(2)
        assertFalse(audio.hasAudioFocus)
        assertEquals(2, client.abandons)
    }

    @Test fun abandonmentFailureStillClearsOwnershipAndAllowsAnotherRequest() {
        val client = FakeAudioFocusClient().apply { failAbandon = true }
        val audio = AudioDuckingManager(client)
        audio.requestTransientFocus(1)
        audio.restoreAudio(1)
        assertFalse(audio.hasAudioFocus)
        assertTrue(audio.requestTransientFocus(2))
        audio.restoreAudio(1)
        assertTrue(audio.hasAudioFocus)
    }
}
