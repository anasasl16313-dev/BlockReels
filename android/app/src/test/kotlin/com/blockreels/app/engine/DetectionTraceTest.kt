package com.blockreels.app.engine

import com.blockreels.app.model.SyntheticNode
import com.blockreels.app.detection.AppPlatform
import org.junit.Assert.*
import org.junit.Test

class DetectionTraceTest {
    @Test
    fun inputFieldsNeverContributeUiLabelHints() {
        val node = SyntheticNode(isEditable = true, text = "Reels", contentDescription = "Share")
        assertNull(node.displayText)
        assertNull(node.displayDescription)
        assertNull(DetectionTrace.NodeSummary.from(node, 0).uiLabelHint)
    }

    @Test
    fun unsupportedLiteCaptureRetainsRelationshipsWithoutScreenTextOrGuessedIds() {
        val node = SyntheticNode(className = "android.widget.Button", isClickable = true,
            text = "private caption contains Reels", contentDescription = "private message")
        val sample = DetectionTrace.NodeSummary.from(node, 2, platform = null,
            packageName = "com.facebook.lite", index = 4, parentIndex = 1)
        assertNull(sample.resourceId)
        assertNull(sample.suppression)
        assertNull(sample.uiLabelHint)
        assertEquals(4, sample.index)
        assertEquals(1, sample.parentIndex)
        assertTrue(sample.clickable)
        assertFalse(sample.toString().contains("private"))
        node.contentDescription = "Reels"
        assertEquals(DetectionTrace.UiLabelHint.REELS,
            DetectionTrace.NodeSummary.from(node, 2, platform = null).uiLabelHint)
    }
    @Test
    fun attachmentLatencyUsesOnlyCorrelatedMonotonicMilestones() {
        val frame = DetectionTrace.Frame("com.instagram.android", 32, 1000L, 7, false,
            receivedUptimeMs = 1010L, evidenceUptimeMs = 1025L, detectionCompletedUptimeMs = 1030L)
        val latency = DetectionTrace.AttachmentLatency.from(frame, 1045L)
        assertEquals(10L, latency.eventDeliveryMs)
        assertEquals(35L, latency.arrivalToAttachMs)
        assertEquals(20L, latency.evidenceToAttachMs)
        assertEquals(15L, latency.detectionToAttachMs)
        assertNull(DetectionTrace.AttachmentLatency.from(frame, 1020L).detectionToAttachMs)
        assertNull(DetectionTrace.AttachmentLatency.from(frame.copy(eventTime = null), 1045L).arrivalToAttachMs)
    }

    @Test
    fun instagramStructureAlsoExcludesCaptionsAndDescriptions() {
        val node = SyntheticNode(viewIdResourceName = "com.instagram.android:id/clips_video_container",
            text = "private caption", contentDescription = "private message")
        val sample = DetectionTrace.NodeSummary.from(node, 1, AppPlatform.INSTAGRAM).toString()
        assertTrue(sample.contains("clips_video_container"))
        assertFalse(sample.contains("private"))
    }
    @Test
    fun structuralSampleOmitsAllScreenTextAndDescriptions() {
        val node = SyntheticNode(
            viewIdResourceName = "com.google.android.youtube:id/reel_recycler",
            className = "android.widget.FrameLayout",
            text = "private caption 789012", contentDescription = "private message 345678"
        )
        val sample = DetectionTrace.NodeSummary.from(node, 2).toString()
        assertTrue(sample.contains("reel_recycler"))
        for (secret in listOf("private", "caption", "message", "789012", "345678")) {
            assertFalse(sample.contains(secret))
        }
    }
}
