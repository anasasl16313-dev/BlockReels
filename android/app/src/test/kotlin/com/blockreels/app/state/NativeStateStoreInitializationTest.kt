package com.blockreels.app.state

import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.preferencesOf
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.blockreels.app.bridge.NativePersistenceException
import com.blockreels.app.bridge.acknowledgePersistence
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import java.io.File
import java.io.IOException
import java.nio.file.Files

class NativeStateStoreInitializationTest {
    private val masterKey = booleanPreferencesKey("master_enabled")

    @Before
    fun reset() = runBlocking { NativeStateStore.resetForTests() }

    @After
    fun cleanUp() = runBlocking { NativeStateStore.resetForTests() }

    @Test
    fun audioDefaultsToEnabledAndMissingSyncFieldPreservesExplicitOptOut() = runBlocking {
        val soundKey = booleanPreferencesKey("sound_enabled")
        val store = TestPreferencesStore()
        NativeStateStore.initialize(store).await()
        assertTrue(NativeStateStore.getInterventionConfig().soundEnabled)
        NativeStateStore.setInterventionConfig(null, InterventionMode.MINDFUL_PAUSE, 7, "Pause", false, true, false)
        NativeStateStore.resetForTests()
        NativeStateStore.initialize(store).await()
        assertFalse(NativeStateStore.getInterventionConfig().soundEnabled)
        NativeStateStore.setInterventionConfig(null, InterventionMode.STRICT_BLOCK, 7, "Pause", null, true, false)
        assertFalse(NativeStateStore.getInterventionConfig().soundEnabled)
        assertEquals(false, store.persisted[soundKey])
    }

    @Test
    fun coldInitializationNeverBlocksWithDefaultsWhenPersistedMasterIsOff() = runBlocking {
        val release = CompletableDeferred<Unit>()
        val store = TestPreferencesStore(preferencesOf(masterKey to false), loadGate = release)
        val completion = NativeStateStore.initialize(store)
        store.loadStarted.await()
        assertFalse(NativeStateStore.isReady())
        assertFalse(NativeStateStore.isAppBlockingActive("com.instagram.android"))
        release.complete(Unit)
        completion.await()
        assertTrue(NativeStateStore.isReady())
        assertFalse(NativeStateStore.isMasterEnabled())
        assertFalse(NativeStateStore.isAppBlockingActive("com.instagram.android"))
    }

    @Test
    fun concurrentInitializeAndWriteShareOneLoadAndKeepTheNewSettings() = runBlocking {
        val release = CompletableDeferred<Unit>()
        val store = TestPreferencesStore(preferencesOf(masterKey to false), loadGate = release)
        val first = NativeStateStore.initialize(store)
        assertSame(first, NativeStateStore.initialize(store))
        store.loadStarted.await()
        val mutation = async(start = CoroutineStart.UNDISPATCHED) {
            acknowledgePersistence { NativeStateStore.updateSettings(mapOf("isMasterEnabled" to true)) }
        }
        assertFalse(mutation.isCompleted)
        assertEquals(0, store.writes.get())
        release.complete(Unit)
        assertTrue(mutation.await())
        assertTrue(NativeStateStore.isMasterEnabled())
        assertEquals(true, store.persisted[masterKey])
        NativeStateStore.initialize(store).await()
        assertEquals(1, store.reads.get())
        assertTrue(NativeStateStore.isMasterEnabled())
    }

    @Test
    fun failedPersistenceReturnsAMeaningfulBridgeFailureWithoutPublishingSettings() = runBlocking {
        val store = TestPreferencesStore(preferencesOf(masterKey to false))
        NativeStateStore.initialize(store).await()
        store.failWrites = true
        try {
            acknowledgePersistence { NativeStateStore.updateSettings(mapOf("isMasterEnabled" to true)) }
            fail("Persistence failure must not acknowledge success")
        } catch (failure: NativePersistenceException) {
            assertEquals("PERSISTENCE_ERROR", NativePersistenceException.CODE)
            assertTrue(failure.message!!.contains("persist"))
            assertTrue(failure.cause is IOException)
        }
        assertFalse(NativeStateStore.isMasterEnabled())
        assertEquals(false, store.persisted[masterKey])
    }

    @Test
    fun restoredProtectionDoesNotPublishAnyPartWhenItsSingleWriteFails() = runBlocking {
        val store = TestPreferencesStore(preferencesOf(masterKey to true))
        NativeStateStore.initialize(store).await()
        val pkg = "com.instagram.android"
        val config = InterventionConfig(mode = InterventionMode.STRICT_BLOCK, holdDurationSeconds = 12)
        val rules = listOf(mapOf("packageName" to pkg, "isEnabled" to false))
        store.failWrites = true
        try {
            acknowledgePersistence {
                NativeStateStore.applyRestoredProtection(null, rules, emptyList(), config, enabled = false)
            }
            fail("Failed restore must not be acknowledged")
        } catch (failure: NativePersistenceException) {
            assertTrue(failure.cause is IOException)
        }
        assertTrue(NativeStateStore.isMasterEnabled())
        assertTrue(NativeStateStore.isAppBlockingActive(pkg))
        assertNull(NativeStateStore.getRule(pkg))
        assertNotEquals(config, NativeStateStore.getInterventionConfig())

        assertEquals(1, store.writes.get())
    }

    @Test
    fun acknowledgementWaitsForPersistenceAndConcurrentWritesAreSerialized() = runBlocking {
        val release = CompletableDeferred<Unit>()
        val store = TestPreferencesStore(preferencesOf(masterKey to false), writeGate = release)
        NativeStateStore.initialize(store).await()
        val first = async(start = CoroutineStart.UNDISPATCHED) {
            acknowledgePersistence { NativeStateStore.updateSettings(mapOf("isMasterEnabled" to true)) }
        }
        store.writeStarted.await()
        val second = async(start = CoroutineStart.UNDISPATCHED) {
            acknowledgePersistence { NativeStateStore.updateSettings(mapOf("isMasterEnabled" to false)) }
        }
        assertFalse(first.isCompleted)
        assertFalse(second.isCompleted)
        assertEquals(1, store.writes.get())
        assertFalse(NativeStateStore.isMasterEnabled())
        release.complete(Unit)
        assertTrue(first.await())
        assertTrue(second.await())
        assertEquals(2, store.writes.get())
        assertEquals(false, store.persisted[masterKey])
        assertFalse(NativeStateStore.isMasterEnabled())
    }

    @Test
    fun successfulAcknowledgementSurvivesDataStoreReopening() = runBlocking {
        val directory = Files.createTempDirectory("native-state-test").toFile()
        val file = File(directory, "state.preferences_pb")
        val firstJob = SupervisorJob()
        val secondJob = SupervisorJob()
        try {
            val firstStore = PreferenceDataStoreFactory.create(
                scope = CoroutineScope(firstJob + Dispatchers.IO), produceFile = { file }
            )
            NativeStateStore.initialize(firstStore).await()
            assertTrue(acknowledgePersistence {
                NativeStateStore.updateSettings(mapOf("isMasterEnabled" to false))
            })
            assertTrue(file.exists())
            NativeStateStore.resetForTests()
            firstJob.cancelAndJoin()
            val reopened = PreferenceDataStoreFactory.create(
                scope = CoroutineScope(secondJob + Dispatchers.IO), produceFile = { file }
            )
            assertEquals(false, reopened.data.first()[masterKey])
            NativeStateStore.initialize(reopened).await()
            assertFalse(NativeStateStore.isAppBlockingActive("com.instagram.android"))
        } finally {
            NativeStateStore.resetForTests()
            firstJob.cancelAndJoin()
            secondJob.cancelAndJoin()
            directory.deleteRecursively()
        }
    }
}
