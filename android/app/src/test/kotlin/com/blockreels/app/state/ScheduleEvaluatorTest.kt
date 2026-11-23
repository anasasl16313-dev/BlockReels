package com.blockreels.app.state

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScheduleEvaluatorTest {

    @Test
    fun testDaytimeScheduleActiveBetween9amAnd5pm() {
        val rule = ScheduleRule(
            id = "work_focus",
            title = "Work Hours",
            isActive = true,
            daysOfWeek = setOf(1, 2, 3, 4, 5), // Mon-Fri (ISO-8601)
            startMinuteOfDay = 9 * 60,         // 540 (09:00)
            endMinuteOfDay = 17 * 60,          // 1020 (17:00)
            enabledPackages = setOf("com.instagram.android")
        )

        // Monday 10:30 AM -> Active
        assertTrue(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 630,
                targetPackage = "com.instagram.android"
            )
        )

        // Monday 08:30 AM -> Inactive (before 9 AM)
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 510,
                targetPackage = "com.instagram.android"
            )
        )

        // Monday 05:30 PM -> Inactive (end-exclusive at 5 PM)
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 1050,
                targetPackage = "com.instagram.android"
            )
        )

        // Sunday 11:00 AM -> Inactive (weekend)
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 7,
                previousIsoDay = 6,
                currentMinuteOfDay = 660,
                targetPackage = "com.instagram.android"
            )
        )

        // Monday 10:30 AM for YouTube -> Inactive (package mismatch)
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 630,
                targetPackage = "com.google.android.youtube"
            )
        )
    }

    @Test
    fun testMidnightWrapAroundScheduleActiveBetween10pmAnd6am() {
        val rule = ScheduleRule(
            id = "night_focus",
            title = "Sleep Hours",
            isActive = true,
            daysOfWeek = setOf(1, 2, 3, 4, 5, 6, 7),
            startMinuteOfDay = 22 * 60,              // 1320 (10:00 PM)
            endMinuteOfDay = 6 * 60,                 // 360  (06:00 AM)
            enabledPackages = emptySet()             // All target apps
        )

        // Monday 11:30 PM -> Active (pre-midnight)
        assertTrue(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 1410,
                targetPackage = "com.instagram.android"
            )
        )

        // Tuesday 03:30 AM -> Active (carry-over from Monday)
        assertTrue(
            rule.isTimeActive(
                currentIsoDay = 2,
                previousIsoDay = 1,
                currentMinuteOfDay = 210,
                targetPackage = "com.instagram.android"
            )
        )

        // Tuesday 06:00 AM exactly -> Inactive (end-exclusive)
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 2,
                previousIsoDay = 1,
                currentMinuteOfDay = 360,
                targetPackage = "com.instagram.android"
            )
        )

        // Tuesday 12:00 PM -> Inactive
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 2,
                previousIsoDay = 1,
                currentMinuteOfDay = 720,
                targetPackage = "com.instagram.android"
            )
        )

        // Tuesday 08:00 PM -> Inactive
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 2,
                previousIsoDay = 1,
                currentMinuteOfDay = 1200,
                targetPackage = "com.instagram.android"
            )
        )
    }

    @Test
    fun testZeroDurationScheduleNeverMatches() {
        val rule = ScheduleRule(
            id = "zero_duration",
            title = "Zero Duration",
            isActive = true,
            daysOfWeek = setOf(1, 2, 3, 4, 5, 6, 7),
            startMinuteOfDay = 10 * 60,
            endMinuteOfDay = 10 * 60,
            enabledPackages = emptySet()
        )

        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 1,
                previousIsoDay = 7,
                currentMinuteOfDay = 600,
                targetPackage = "com.instagram.android"
            )
        )
    }

    @Test
    fun testInactiveScheduleNeverMatches() {
        val rule = ScheduleRule(
            id = "disabled_rule",
            title = "Disabled",
            isActive = false,
            daysOfWeek = setOf(1, 2, 3, 4, 5, 6, 7),
            startMinuteOfDay = 0,
            endMinuteOfDay = 1439,
            enabledPackages = emptySet()
        )

        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 2,
                previousIsoDay = 1,
                currentMinuteOfDay = 700,
                targetPackage = "com.instagram.android"
            )
        )
    }

    @Test
    fun testQuickBoostIsOneShotAndDoesNotRepeatNextWeek() {
        val startedAt = 1_767_225_600_000L
        val rule = ScheduleRule(
            id = "quick_boost_$startedAt",
            title = "25m Pomodoro",
            isActive = true,
            daysOfWeek = setOf(4),
            startMinuteOfDay = 10 * 60,
            endMinuteOfDay = 10 * 60 + 25,
            enabledPackages = setOf("com.google.android.youtube")
        )

        assertTrue(
            rule.isTimeActive(
                currentIsoDay = 4,
                previousIsoDay = 3,
                currentMinuteOfDay = 605,
                targetPackage = "com.google.android.youtube",
                nowMillis = startedAt + 5 * 60_000L
            )
        )
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 4,
                previousIsoDay = 3,
                currentMinuteOfDay = 605,
                targetPackage = "com.google.android.youtube",
                nowMillis = startedAt + 7 * 24 * 60 * 60_000L + 5 * 60_000L
            )
        )
        assertFalse(
            rule.isTimeActive(
                currentIsoDay = 4,
                previousIsoDay = 3,
                currentMinuteOfDay = 605,
                targetPackage = "com.google.android.youtube",
                nowMillis = startedAt + 25 * 60_000L
            )
        )
    }
}
