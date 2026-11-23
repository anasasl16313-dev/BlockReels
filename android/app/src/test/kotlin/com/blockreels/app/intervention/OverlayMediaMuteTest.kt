package com.blockreels.app.intervention

import com.blockreels.app.state.InterventionMode
import org.junit.Assert.*
import org.junit.Test

class OverlayMediaMuteTest {
    private class Stream : OverlayMediaMute.Stream {
        override var isFixed = false
        var mutedState = false
        override val isMuted get() = mutedState
        val requests = mutableListOf<Boolean>()
        override fun setMuted(muted: Boolean) {
            requests.add(muted)
            this.mutedState = muted
        }
    }

    private class Journal : OverlayMediaMute.Journal {
        var boot: Int? = null
        override fun read() = boot
        override fun write(boot: Int): Boolean {
            this.boot = boot
            return true
        }
        override fun clear() { boot = null }
    }

    @Test fun tiktokCoverSilencesOnlyWhileAttachedAndDoesNotPausePlayback() {
        val stream = Stream()
        val journal = Journal()
        var pauseAttempts = 0
        val fixture = InterventionAudioCleanupTest.Fixture(
            mediaMute = OverlayMediaMute(stream, journal) { 7 },
            onTikTokOverlayAttached = { _, _ -> pauseAttempts++ }
        )
        fixture.overlay.attachOnShow = false
        fixture.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        val cover = fixture.overlay.calls.single()
        assertFalse(stream.isMuted)
        fixture.overlay.isOverlayAttached = true
        cover.attached()
        assertTrue(stream.isMuted)
        assertEquals(0, pauseAttempts)
        assertEquals(0, fixture.client.requests)
        cover.unlock()
        cover.attached() // A stale callback has no right to mute after unlock.
        assertFalse(stream.isMuted)
        assertNull(journal.boot)
        assertEquals(listOf(true, false), stream.requests)
    }

    @Test fun releaseNeverUnmutesPreexistingUserMuteOrNewerOwner() {
        val stream = Stream().apply { mutedState = true }
        val mute = OverlayMediaMute(stream, Journal()) { 7 }
        assertTrue(mute.acquire(1))
        mute.release(1)
        assertTrue(stream.isMuted)
        assertTrue(stream.requests.isEmpty())
        stream.mutedState = false
        assertTrue(mute.acquire(2))
        mute.release(1)
        assertTrue(stream.isMuted)
        mute.release(2)
        assertFalse(stream.isMuted)
    }

    @Test fun recoveryRestoresSameBootAndDropsOldRebootMarker() {
        for (boot in listOf(7, 8)) {
            val stream = Stream()
            val journal = Journal()
            assertTrue(OverlayMediaMute(stream, journal) { 7 }.acquire(1))
            OverlayMediaMute(stream, journal) { boot }.recover()
            assertEquals(boot != 7, stream.isMuted)
            assertNull(journal.boot)
        }
    }

    @Test fun fixedVolumeUsesExistingFallbackAndDoesNotWriteRecoveryMarker() {
        val stream = Stream().apply { isFixed = true }
        val journal = Journal()
        var pauseAttempts = 0
        val fixture = InterventionAudioCleanupTest.Fixture(focusGranted = false,
            mediaMute = OverlayMediaMute(stream, journal) { 7 },
            onTikTokOverlayAttached = { _, _ -> pauseAttempts++ })
        fixture.execute(InterventionMode.MINDFUL_PAUSE, "com.zhiliaoapp.musically")
        assertEquals(1, pauseAttempts)
        assertTrue(stream.requests.isEmpty())
        assertNull(journal.boot)
    }
}
