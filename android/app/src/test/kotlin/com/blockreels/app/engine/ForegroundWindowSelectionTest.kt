package com.blockreels.app.engine

import android.view.accessibility.AccessibilityWindowInfo
import org.junit.Assert.*
import org.junit.Test

class ForegroundWindowSelectionTest {
    @Test fun missingWindowMetadataCanRecoverOnlyTheExpectedActiveTarget() {
        val pkg = "com.google.android.youtube"
        fun accepts(selected: Int? = null, type: Int? = null, rootPackage: String? = pkg,
                    expected: String? = pkg) =
            ForegroundWindowSelection.acceptsActiveRoot(selected, 7, type, rootPackage, expected)
        assertTrue(accepts())
        assertFalse(accepts(selected = 8))
        assertFalse(accepts(type = AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY))
        assertFalse(accepts(type = AccessibilityWindowInfo.TYPE_SYSTEM))
        assertFalse(accepts(rootPackage = "com.instagram.android"))
        assertFalse(accepts(expected = null))
        assertFalse(accepts(rootPackage = "launcher", expected = "launcher"))
    }

    @Test fun focusedSystemWindowDoesNotDisplaceActiveApplication() {
        val system = ForegroundWindowSelection.Window(10, AccessibilityWindowInfo.TYPE_SYSTEM, true, true)
        val youtube = ForegroundWindowSelection.Window(7, AccessibilityWindowInfo.TYPE_APPLICATION, false, true)
        assertEquals(7, ForegroundWindowSelection.select(listOf(system, youtube)))
        assertNull(ForegroundWindowSelection.select(listOf(system)))
    }

    @Test fun overlayAndKeyboardDoNotMasqueradeAsForegroundAppChanges() {
        val selected = ForegroundWindowSelection.select(listOf(
            ForegroundWindowSelection.Window(10, AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY, false, true),
            ForegroundWindowSelection.Window(11, AccessibilityWindowInfo.TYPE_INPUT_METHOD, true, false),
            ForegroundWindowSelection.Window(7, AccessibilityWindowInfo.TYPE_APPLICATION, false, true)
        ))
        assertEquals(7, selected)
    }

    @Test fun launcherFocusWinsOverOldApplicationAndItsOverlay() {
        val selected = ForegroundWindowSelection.select(listOf(
            ForegroundWindowSelection.Window(10, AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY, false, true),
            ForegroundWindowSelection.Window(7, AccessibilityWindowInfo.TYPE_APPLICATION, false, false),
            ForegroundWindowSelection.Window(8, AccessibilityWindowInfo.TYPE_APPLICATION, true, false)
        ))
        assertEquals(8, selected)
        assertNull(ForegroundWindowSelection.select(listOf(
            ForegroundWindowSelection.Window(10, AccessibilityWindowInfo.TYPE_ACCESSIBILITY_OVERLAY, true, true)
        )))
    }
}
