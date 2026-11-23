package com.blockreels.app.state

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.emptyPreferences
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import java.io.IOException
import java.util.concurrent.atomic.AtomicInteger

/** Controlled DataStore boundaries; all production coordination remains in NativeStateStore. */
internal class TestPreferencesStore(
    @Volatile var persisted: Preferences = emptyPreferences(),
    val loadGate: CompletableDeferred<Unit>? = null,
    val writeGate: CompletableDeferred<Unit>? = null
) : DataStore<Preferences> {
    val loadStarted = CompletableDeferred<Unit>()
    val writeStarted = CompletableDeferred<Unit>()
    val reads = AtomicInteger(0)
    val writes = AtomicInteger(0)
    var failWrites = false

    override val data: Flow<Preferences> = flow {
        reads.incrementAndGet()
        val snapshot = persisted
        loadStarted.complete(Unit)
        loadGate?.await()
        emit(snapshot)
    }

    override suspend fun updateData(transform: suspend (Preferences) -> Preferences): Preferences {
        writes.incrementAndGet()
        writeStarted.complete(Unit)
        writeGate?.await()
        if (failWrites) throw IOException("Injected DataStore write failure")
        return transform(persisted).also { persisted = it }
    }
}
