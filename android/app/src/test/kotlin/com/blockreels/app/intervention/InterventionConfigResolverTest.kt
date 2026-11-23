package com.blockreels.app.intervention

import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.InterventionMode
import com.blockreels.app.state.RuleConfig
import org.junit.Assert.assertEquals
import org.junit.Test

class InterventionConfigResolverTest {

    @Test
    fun ruleModeOverrideKeepsGlobalEightSecondHold() {
        val base = InterventionConfig(
            mode = InterventionMode.MINDFUL_PAUSE,
            holdDurationSeconds = 8
        )
        val legacyRule = RuleConfig(
            packageName = "com.instagram.android",
            isEnabled = true,
            mode = InterventionMode.STRICT_BLOCK,
            holdDurationSeconds = 10
        )

        val resolved = InterventionConfigResolver.resolve(base, legacyRule)

        assertEquals(InterventionMode.STRICT_BLOCK, resolved.mode)
        assertEquals(8, resolved.holdDurationSeconds)
    }

    @Test
    fun noRuleUsesGlobalConfigUnchanged() {
        val base = InterventionConfig(
            mode = InterventionMode.MINDFUL_PAUSE,
            holdDurationSeconds = 8
        )

        val resolved = InterventionConfigResolver.resolve(base, null)

        assertEquals(base, resolved)
    }
}
