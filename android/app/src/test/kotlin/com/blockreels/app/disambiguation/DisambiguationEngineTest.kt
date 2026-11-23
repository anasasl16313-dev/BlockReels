package com.blockreels.app.disambiguation

import com.blockreels.app.detection.AppPlatform
import com.blockreels.app.detection.SuppressionReason
import com.blockreels.app.model.SyntheticNode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DisambiguationEngineTest {

    @Test
    fun testChatComposerSuppressedOnAllPlatforms() {
        val platforms = listOf(
            AppPlatform.INSTAGRAM to "com.instagram.android:id/row_thread_composer",
            AppPlatform.YOUTUBE to "com.google.android.youtube:id/comment_composer",
            AppPlatform.FACEBOOK to "com.facebook.katana:id/message_composer",
            AppPlatform.TIKTOK to "com.zhiliaoapp.musically:id/im_chat_edit_text"
        )

        for ((platform, viewId) in platforms) {
            val node = SyntheticNode(viewIdResourceName = viewId, isEditable = true)
            val reason = DisambiguationEngine.checkSuppression(node, platform)
            assertEquals("Expected chat composer suppression for $platform", SuppressionReason.CHAT_COMPOSER_ACTIVE, reason)
        }
    }

    @Test
    fun testGenericEditTextTriggersChatComposerSuppression() {
        val node = SyntheticNode(className = "android.widget.EditText")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.INSTAGRAM)
        assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, reason)
    }

    @Test
    fun testChatContainerTriggersChatThreadContainerSuppression() {
        val node = SyntheticNode(viewIdResourceName = "com.instagram.android:id/direct_message_list")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.INSTAGRAM)
        assertEquals(SuppressionReason.CHAT_THREAD_CONTAINER, reason)
    }

    @Test
    fun testProfileHeaderSuppressedOnAllPlatforms() {
        val platforms = listOf(
            AppPlatform.INSTAGRAM to "com.instagram.android:id/unified_profile_layout",
            AppPlatform.YOUTUBE to "com.google.android.youtube:id/channel_header",
            AppPlatform.FACEBOOK to "com.facebook.katana:id/profile_header_container",
            AppPlatform.TIKTOK to "com.zhiliaoapp.musically:id/profile_header"
        )

        for ((platform, viewId) in platforms) {
            val node = SyntheticNode(viewIdResourceName = viewId)
            val reason = DisambiguationEngine.checkSuppression(node, platform)
            assertEquals("Expected profile header suppression for $platform", SuppressionReason.PROFILE_HEADER_DETECTED, reason)
        }
    }

    @Test
    fun testYouTubeTimeScrubberInTextTriggersStandardFeedScrubber() {
        val node = SyntheticNode(text = "03:45 / 12:30")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.YOUTUBE)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, reason)
    }

    @Test
    fun testYouTubeTimeScrubberInContentDescTriggersStandardFeedScrubber() {
        val node = SyntheticNode(contentDescription = "Current time 01:20 / 10:00")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.YOUTUBE)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, reason)
    }

    @Test
    fun testYouTubeStandardPlayerViewIdTriggersStandardFeedScrubber() {
        val node = SyntheticNode(viewIdResourceName = "com.google.android.youtube:id/watch_while_layout")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.YOUTUBE)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, reason)
    }

    @Test
    fun testInstagramExploreGridTriggersSearchExploreGridActive() {
        val node = SyntheticNode(viewIdResourceName = "com.instagram.android:id/explore_grid_recycler")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.INSTAGRAM)
        assertEquals(SuppressionReason.SEARCH_EXPLORE_GRID_ACTIVE, reason)
    }

    @Test
    fun testTikTokCreatorCameraTriggersCreatorCameraActive() {
        val node = SyntheticNode(viewIdResourceName = "com.zhiliaoapp.musically:id/camera_surface")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.TIKTOK)
        assertEquals(SuppressionReason.CREATOR_CAMERA_ACTIVE, reason)
    }

    @Test
    fun testNeutralReelNodeReturnsNullSuppression() {
        val node = SyntheticNode(viewIdResourceName = "com.instagram.android:id/clips_video_container")
        val reason = DisambiguationEngine.checkSuppression(node, AppPlatform.INSTAGRAM)
        assertNull("Neutral reel container should NOT be suppressed", reason)
    }
}
