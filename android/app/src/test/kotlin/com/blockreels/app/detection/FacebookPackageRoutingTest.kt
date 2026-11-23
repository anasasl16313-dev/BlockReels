package com.blockreels.app.detection

import com.blockreels.app.state.NativeStateStore
import com.blockreels.app.state.TestPreferencesStore
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class FacebookPackageRoutingTest {
    @Test fun liteHasASelectiveDetectorWhileMessengerRemainsOutsideProtection() {
        val registry = DetectorRegistry()
        assertEquals(AppPlatform.FACEBOOK, AppPlatform.fromPackageName("com.facebook.katana"))
        assertTrue(registry.getDetectorForPackage("com.facebook.katana") is FacebookDetector)
        assertEquals(AppPlatform.FACEBOOK, AppPlatform.fromPackageName(AppPlatform.FACEBOOK_LITE_PACKAGE))
        assertTrue(registry.getDetectorForPackage(AppPlatform.FACEBOOK_LITE_PACKAGE) is FacebookDetector)
        assertNull(AppPlatform.fromPackageName("com.facebook.orca"))
        assertNull(registry.getDetectorForPackage("com.facebook.orca"))
    }

    @Test fun standardFacebookUsesItsOwnNativeToggleAndRuleKey() = runBlocking {
        NativeStateStore.resetForTests()
        try {
            NativeStateStore.initialize(TestPreferencesStore()).await()
            val facebook = AppPlatform.FACEBOOK.packageName
            val lite = AppPlatform.FACEBOOK_LITE_PACKAGE
            assertEquals(false, NativeStateStore.getAppToggles()[facebook])
            assertFalse(NativeStateStore.isAppBlockingActive(facebook))
            assertNull(NativeStateStore.getRule(facebook))

            NativeStateStore.setAppTogglesInMemory(mapOf(lite to true))
            assertFalse(NativeStateStore.isAppBlockingActive(facebook))
            assertTrue(NativeStateStore.isAppBlockingActive(lite))
            assertNotNull(DetectorRegistry().getDetectorForPackage(lite))
            NativeStateStore.setAppTogglesInMemory(mapOf(facebook to true))
            assertTrue(NativeStateStore.isAppBlockingActive(facebook))
            assertFalse(NativeStateStore.isAppBlockingActive(lite))
        } finally {
            NativeStateStore.resetForTests()
        }
    }
}
