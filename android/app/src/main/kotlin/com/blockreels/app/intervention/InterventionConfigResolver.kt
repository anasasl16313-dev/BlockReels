package com.blockreels.app.intervention

import com.blockreels.app.state.InterventionConfig
import com.blockreels.app.state.RuleConfig

/**
 * Resolves the effective intervention configuration for a package.
 *
 * Per-app rules customize the intervention mode only. Hold duration is a
 * single global friction setting so the 8s/10s/whatever value the user picks
 * in Settings is what the native overlay actually counts down.
 */
object InterventionConfigResolver {
    fun resolve(base: InterventionConfig, rule: RuleConfig?): InterventionConfig {
        return if (rule == null) base else base.copy(mode = rule.mode)
    }
}
