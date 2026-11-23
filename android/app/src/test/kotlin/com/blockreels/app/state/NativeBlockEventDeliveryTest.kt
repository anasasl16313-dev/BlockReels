package com.blockreels.app.state

import com.blockreels.app.detection.DetectionLayer
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.IOException
import java.util.concurrent.CopyOnWriteArrayList

class NativeBlockEventDeliveryTest {
    @Before
    fun initialize() = runBlocking {
        NativeStateStore.resetForTests()
        NativeStateStore.initialize(TestPreferencesStore()).await()
    }

    @After
    fun reset() = runBlocking { NativeStateStore.resetForTests() }

    @Test
    fun publishesOnlyAfterStorageWithTheSameStableIdAndNoScreenText() = runBlocking {
        val entered = CompletableDeferred<PendingBlockEvent>()
        val release = CompletableDeferred<Unit>()
        val published = CopyOnWriteArrayList<Map<String, Any>>()
        NativeStateStore.blockEventWriterForTests = { event ->
            entered.complete(event)
            release.await()
        }
        NativeStateStore.eventBroadcaster = { published.add(it) }
        val writing = NativeStateStore.recordBlockEvent("com.instagram.android", "private screen text")
        val stored = entered.await()
        assertTrue(published.isEmpty())
        assertTrue(stored.eventId.isNotBlank())
        assertEquals("REEL_CONTAINER_MATCH", stored.detectionReason)
        release.complete(Unit)
        writing.join()
        assertEquals(1, published.size)
        assertEquals(stored.eventId, published.single()["eventId"])
        assertFalse(published.single().toString().contains("private screen text"))
    }

    @Test
    fun newEventsKeepOnlyKnownCodesEvenWhenCaptionsLookLikeIdentifiers() {
        for (raw in listOf("a private caption", "PRIVATE_CAPTION", "com.instagram.android:id/private_caption")) {
            val event = PendingBlockEvent.create(1L, "com.instagram.android", "INSTAGRAM", "AUTO_BACK", raw)
            assertEquals("REEL_CONTAINER_MATCH", event.detectionReason)
            assertFalse(event.toWireMap().toString().contains(raw))
        }
        for (code in DetectionLayer.values().map { it.name } + listOf("SURGICAL_HEURISTIC", "REEL_CONTAINER_MATCH", "CLIPS_CONTAINER")) {
            val event = PendingBlockEvent.create(1L, "com.instagram.android", "INSTAGRAM", "AUTO_BACK", code)
            assertEquals(code, event.detectionReason)
        }
    }

    @Test
    fun storageFailureDoesNotDisableBlockingOrPublishAnUnstoredEvent() = runBlocking {
        val published = CopyOnWriteArrayList<Map<String, Any>>()
        NativeStateStore.blockEventWriterForTests = { throw IOException("Injected event write failure") }
        NativeStateStore.eventBroadcaster = { published.add(it) }
        NativeStateStore.recordBlockEvent("com.instagram.android", "PRIMARY_RESOURCE_ID").join()
        assertTrue(NativeStateStore.isAppBlockingActive("com.instagram.android"))
        assertEquals(1, NativeStateStore.getMetricsSnapshot()["totalBlockedToday"])
        assertTrue(published.isEmpty())
    }
}
