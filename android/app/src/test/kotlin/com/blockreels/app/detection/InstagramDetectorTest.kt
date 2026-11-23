package com.blockreels.app.detection

import com.blockreels.app.engine.TraversalEngine
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class InstagramDetectorTest {

    // Synthetic regressions using existing repository IDs, not device captures.
    @Test
    fun sharedProfileWrapperDoesNotHideActiveReelsViewer() {
        val root = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/profile_header_container") {
                node("com.instagram.android:id/clips_viewer_view_pager")
            }
        }
        assertTrue(detector.evaluate(root, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun sharedFeedAndUnfocusedEditorDoNotVetoDefinitiveViewer() {
        val root = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/feed_recycler_view", bounds = intArrayOf(0, 0, 1080, 1000))
            node(className = "android.widget.EditText", isEditable = true)
            node("com.instagram.android:id/clips_viewer_view_pager")
        }
        assertTrue(detector.evaluate(root, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun foregroundDmSearchAndFocusedCommentStillSuppressViewerCandidates() {
        for (context in listOf("direct_thread_layout", "action_bar_search_edit_text", "explore_grid_recycler")) {
            val root = syntheticTree("com.instagram.android") {
                node("com.instagram.android:id/$context")
                node("com.instagram.android:id/clips_viewer_view_pager")
            }
            assertFalse(detector.evaluate(root, traversalEngine = traversalEngine).isMatch)
        }
        val editor = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/clips_video_container")
            node(className = "android.widget.EditText", isEditable = true, isFocused = true)
        }
        assertFalse(detector.evaluate(editor, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun hiddenAndOffscreenViewerPagesCannotMatch() {
        for ((visible, bounds) in listOf(false to intArrayOf(0, 0, 1080, 2400),
            true to intArrayOf(0, 2500, 1080, 4900))) {
            val root = syntheticTree("com.instagram.android") {
                node("com.instagram.android:id/clips_video_container", isVisibleToUser = visible, bounds = bounds)
            }
            assertFalse(detector.evaluate(root, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun feedPreviewsAndStorySizedTitleOrAudioControlsDoNotMatch() {
        // Abstract negative layouts, not observed Story resource IDs.
        for (id in listOf("clips_video_container", "reel_viewer_title")) {
            val root = syntheticTree("com.instagram.android") {
                node("com.instagram.android:id/$id", bounds = intArrayOf(0, 200, 1080, 900))
                node(text = "Original audio", bounds = intArrayOf(0, 2100, 600, 2200))
            }
            assertFalse(detector.evaluate(root, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun viewerBeyondBudgetRemainsUnmatchedAndReportsTruncation() {
        val root = syntheticTree("com.instagram.android") {
            repeat(155) { node(className = "android.view.View") }
            node("com.instagram.android:id/clips_viewer_view_pager")
        }
        val result = detector.evaluate(root, traversalEngine = traversalEngine)
        assertFalse(result.isMatch)
        assertEquals(150, result.stats.nodesEvaluated)
        assertTrue(result.stats.budgetExhausted)
    }

    private lateinit var detector: InstagramDetector
    private lateinit var traversalEngine: TraversalEngine

    @Before
    fun setUp() {
        detector = InstagramDetector()
        traversalEngine = TraversalEngine(maxDepth = 12, maxBudget = 150)
    }

    @Test
    fun testInstagramReelsPrimaryContainerMatchesDefinitive() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/root_layout") {
                node("com.instagram.android:id/clips_viewer_view_pager") {
                    node("com.instagram.android:id/clips_video_container")
                }
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue("Expected positive match for clips_viewer_view_pager", result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals(DetectionLayer.PRIMARY_RESOURCE_ID, result.layerMatched)
    }

    @Test
    fun testInstagramReelsTabDoesNotMatch() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/action_bar")
            node(
                "com.instagram.android:id/reels_tab",
                contentDescription = "Reels",
                bounds = intArrayOf(850, 2200, 1080, 2350)
            )
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Reels tab must NOT block the home feed", result.isMatch)
    }

    @Test
    fun testInstagramHomeFeedDoesNotMatch() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/feed_recycler_view") {
                node(text = "Suggested reel", bounds = intArrayOf(0, 400, 1080, 500))
                node(text = "Original audio", bounds = intArrayOf(0, 500, 1080, 600))
            }
            node("com.instagram.android:id/reels_tab", contentDescription = "Reels")
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Standard Instagram feed must NOT be blocked", result.isMatch)
    }

    @Test
    fun testInstagramReelsAuthorAndActionButtonsMatchDefinitive() {
        val pkg = "com.instagram.android"
        val tree = syntheticTree(pkg) {
            node("$pkg:id/feed_recycler_view")
            node(className = "android.widget.FrameLayout") {
                node("$pkg:id/clips_video_container", bounds = intArrayOf(0, 0, 0, 0))
                node("$pkg:id/clips_author_container", bounds = intArrayOf(24, 1880, 600, 1960))
                node("$pkg:id/clips_action_button", bounds = intArrayOf(920, 1400, 1060, 1540))
            }
        }
        var evidenceSeen = false
        val result = detector.evaluateWithTrace(tree, traversalEngine, onViewerEvidence = { evidenceSeen = true })
        assertTrue(evidenceSeen)
        assertTrue(result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals("$pkg:id/clips_action_button", result.matchedIdentifier)
    }

    @Test
    fun storyViewerTitleAndAudioDoNotMatchWithoutClipsArchitecture() {
        val pkg = "com.instagram.android"
        val tree = syntheticTree(pkg) {
            node("$pkg:id/reel_viewer_tall_shadow") {
                node("$pkg:id/reel_viewer_title", bounds = intArrayOf(24, 100, 600, 180))
                node(contentDescription = "Original audio")
            }
        }
        assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun storyNamedTitleCanCorroborateAnExplicitClipsViewer() {
        val pkg = "com.instagram.android"
        val tree = syntheticTree(pkg) {
            node("$pkg:id/clips_viewer_surface", bounds = intArrayOf(0, 300, 1080, 1200)) {
                node("$pkg:id/reel_viewer_title", bounds = intArrayOf(24, 330, 600, 410))
            }
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue(result.isMatch)
        assertEquals("$pkg:id/reel_viewer_title", result.matchedIdentifier)
    }

    @Test
    fun previewControlsDoNotCombineInsideFeedOrAcrossViewportBranches() {
        val pkg = "com.instagram.android"
        val author = intArrayOf(24, 1880, 600, 1960)
        val action = intArrayOf(920, 1400, 1060, 1540)
        val feed = syntheticTree(pkg) {
            node("$pkg:id/feed_recycler_view") {
                node("$pkg:id/clips_author_container", bounds = author)
                node("$pkg:id/clips_action_button", bounds = action)
            }
        }
        val separateBranches = syntheticTree(pkg) {
            node(className = "android.widget.FrameLayout") {
                node("$pkg:id/clips_author_container", bounds = author)
            }
            node(className = "android.widget.FrameLayout") {
                node("$pkg:id/clips_action_button", bounds = action)
            }
        }
        assertFalse(detector.evaluate(feed, traversalEngine = traversalEngine).isMatch)
        assertFalse(detector.evaluate(separateBranches, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun testInstagramFallbackRegexIdMatchesHigh() {
        val fallbackIds = listOf(
            "com.instagram.android:id/clips_ufi_container",
            "com.instagram.android:id/clips_viewer_overlay",
            "com.instagram.android:id/clips_author_badge"
        )

        for (id in fallbackIds) {
            val tree = syntheticTree("com.instagram.android") {
                node(id)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for fallback id $id", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.FALLBACK_REGEX_ID, result.layerMatched)
        }
    }

    @Test
    fun testInstagramMultilingualContentDescriptionsMatchHigh() {
        val descriptions = mapOf(
            "EN" to "Reel by @creator",
            "ES" to "Reel de @creator",
            "FR" to "Reel par @creator",
            "DE" to "Reel von @creator",
            "PT" to "Reel do @creator",
            "AR" to "مقطع ريلز بواسطة",
            "HI" to "रील्स",
            "JA" to "リール",
            "KO" to "릴스",
            "ID" to "Reels viewer"
        )

        for ((lang, desc) in descriptions) {
            val pkg = "com.instagram.android"
            val tree = syntheticTree(pkg) {
                node("$pkg:id/clips_viewer_surface", bounds = intArrayOf(0, 300, 1080, 1200)) {
                    node(contentDescription = desc, bounds = intArrayOf(24, 330, 600, 410))
                }
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for $lang: $desc", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.CONTENT_DESCRIPTION, result.layerMatched)
        }
    }

    @Test
    fun testInstagramMultilingualTextRegexMatchesMedium() {
        val texts = listOf("Audio original", "Remixt", "Original audio", "مقطع ريلز", "リール", "릴스", "रील्स")

        for (txt in texts) {
            val pkg = "com.instagram.android"
            val tree = syntheticTree(pkg) {
                node("$pkg:id/clips_viewer_surface", bounds = intArrayOf(0, 300, 1080, 1200)) {
                    node(text = txt, bounds = intArrayOf(24, 330, 600, 410))
                }
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for text: $txt", result.isMatch)
            assertEquals(DetectionConfidence.MEDIUM, result.confidence)
            assertEquals(DetectionLayer.MULTILINGUAL_TEXT, result.layerMatched)
        }
    }

    @Test
    fun testInstagramDMComposerSuppressesBlocking() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/thread_container") {
                // Shared reel in message thread
                node("com.instagram.android:id/row_message_reel_share") {
                    node("com.instagram.android:id/clips_thumbnail", contentDescription = "Reel by @creator")
                }
                // Active chat composer at bottom
                node("com.instagram.android:id/row_thread_composer") {
                    node(className = "android.widget.EditText", text = "Hey watch this")
                }
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("DM chat must NOT be blocked", result.isMatch)
        assertTrue("Expected disambiguation suppression", result.disambiguationSuppressed)
        assertTrue(result.foregroundSuppressionConfirmed)
        assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, result.suppressionReason)
    }

    @Test
    fun testInstagramProfileBioAndHeaderSuppressesBlocking() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/unified_profile_layout") {
                node("com.instagram.android:id/user_bio_text", text = "Creator | Daily Reels")
                node("com.instagram.android:id/profile_tab", text = "Reels")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Profile viewing must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.PROFILE_HEADER_DETECTED, result.suppressionReason)
        assertTrue(result.foregroundSuppressionConfirmed)
    }

    @Test
    fun testInstagramExploreGridSuppressesBlocking() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/explore_grid_recycler") {
                node(contentDescription = "Reel by creator 1")
                node(contentDescription = "Reel by creator 2")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Explore grid must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.SEARCH_EXPLORE_GRID_ACTIVE, result.suppressionReason)
    }

    @Test
    fun testInstagramNonMatchingScreenReturnsNegative() {
        val tree = syntheticTree("com.instagram.android") {
            node("com.instagram.android:id/action_bar_title", text = "Edit Settings")
            node("com.instagram.android:id/settings_list")
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Settings screen must NOT match", result.isMatch)
    }
}
