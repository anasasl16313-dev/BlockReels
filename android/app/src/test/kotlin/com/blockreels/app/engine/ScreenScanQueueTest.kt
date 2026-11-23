package com.blockreels.app.engine

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class ScreenScanQueueTest {
    @Test fun blockedTreeReadLeavesUiResponsiveAndDiscardsPreExitWork() = runBlocking {
        val uiThread = Thread.currentThread()
        val scope = CoroutineScope(coroutineContext + Job())
        val started = CompletableDeferred<Thread>()
        val release = CountDownLatch(1)
        val delivered = CompletableDeferred<Int>()
        val reads = mutableListOf<Int>()
        val queue = ScreenScanQueue<Int, Int>(scope, Dispatchers.IO, { request, isCurrent ->
            reads.add(request)
            if (request == 0) {
                started.complete(Thread.currentThread())
                check(release.await(5, TimeUnit.SECONDS))
                assertFalse(isCurrent())
            }
            request
        }, { _, result ->
            assertSame(uiThread, Thread.currentThread())
            delivered.complete(result)
        })
        try {
            queue.submit(0)
            withTimeout(5000) { assertNotSame(uiThread, started.await()) }
            repeat(100) { queue.submit(1) }
            queue.invalidate() // Leave while the old app is still supplying child nodes.
            repeat(100) { queue.submit(2) }
            queue.submit(3)
            release.countDown()
            withTimeout(5000) { assertEquals(3, delivered.await()) }
            assertEquals(listOf(0, 3), reads)
        } finally {
            release.countDown()
            scope.cancel()
        }
    }
}
