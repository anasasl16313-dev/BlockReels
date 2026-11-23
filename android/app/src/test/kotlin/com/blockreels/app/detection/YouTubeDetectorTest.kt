package com.blockreels.app.detection

import com.blockreels.app.engine.TraversalEngine
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class YouTubeDetectorTest {

    // Synthetic regressions, not captures of an installed YouTube hierarchy.
    @Test
    fun reelWatchFragmentRootMatchesDefinitive() {
        val id = "com.google.android.youtube:id/reel_watch_fragment_root"
        val tree = syntheticTree("com.google.android.youtube") {
            node(id, bounds = intArrayOf(0, 100, 1080, 2300))
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue(result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals(id, result.matchedIdentifier)
    }

    @Test
    fun narrowProgressBarOrMultilingualDescriptionCanConfirmEnclosingViewer() {
        val pkg = "com.google.android.youtube"
        val indicatorBounds = intArrayOf(180, 1900, 900, 1930)
        for ((id, description, expectedLayer) in listOf(
            Triple("$pkg:id/reel_progress_bar", null, DetectionLayer.FALLBACK_REGEX_ID),
            Triple(null, "مشغل الفيديوهات القصيرة", DetectionLayer.CONTENT_DESCRIPTION)
        )) {
            val tree = syntheticTree(pkg) {
                node(text = "Shorts viewer", bounds = intArrayOf(0, 100, 1080, 2300)) {
                    node(className = "android.widget.FrameLayout") {
                        node(id, contentDescription = description, bounds = indicatorBounds)
                    }
                }
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue(result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(expectedLayer, result.layerMatched)
        }
    }

    @Test
    fun narrowIndicatorsWithoutViewerAncestryDoNotBlock() {
        val pkg = "com.google.android.youtube"
        val tree = syntheticTree(pkg) {
            node(className = "android.widget.FrameLayout") {
                node("$pkg:id/reel_progress_bar", bounds = intArrayOf(180, 1900, 900, 1930))
                node(contentDescription = "مشغل الفيديوهات القصيرة", bounds = intArrayOf(800, 500, 950, 580))
                node(text = "ショート")
            }
        }
        assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun letterboxedPlayerChildUsesItsOwnViewerBranch() {
        val pkg = "com.google.android.youtube"
        val childBounds = intArrayOf(0, 500, 1080, 1900)
        for (insideViewer in listOf(false, true)) {
            val tree = syntheticTree(pkg) {
                node("$pkg:id/reel_watch_fragment_container") {
                    if (insideViewer) node("$pkg:id/reel_video", bounds = childBounds)
                }
                if (!insideViewer) node("$pkg:id/reel_video", bounds = childBounds)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue(result.isMatch)
            assertEquals(
                if (insideViewer) DetectionConfidence.DEFINITIVE else DetectionConfidence.HIGH,
                result.confidence
            )
        }
    }

    @Test
    fun foregroundSearchChannelComposerAndLongFormScrubberOverrideStaleViewer() {
        val pkg = "com.google.android.youtube"
        for ((id, reason) in listOf(
            "search_edit_text" to SuppressionReason.SEARCH_EXPLORE_GRID_ACTIVE,
            "channel_header" to SuppressionReason.PROFILE_HEADER_DETECTED,
            "comment_composer" to SuppressionReason.CHAT_COMPOSER_ACTIVE,
            "time_bar_scrubber" to SuppressionReason.STANDARD_FEED_SCRUBBER
        )) {
            val tree = syntheticTree(pkg) {
                node("$pkg:id/reel_watch_fragment_root")
                node("$pkg:id/$id", bounds = intArrayOf(0, 50, 1080, 150))
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertFalse("Expected $id to keep foreground usable", result.isMatch)
            assertEquals(reason, result.suppressionReason)
        }
    }

    @Test
    fun sharedPlayerAncestorMustNotHideFullScreenShorts() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/watch_while_layout") {
                node("com.google.android.youtube:id/player_view") {
                    node("com.google.android.youtube:id/reel_recycler")
                }
            }
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue("Shared ancestors must not halt before the viewer", result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
    }

    @Test
    fun sharedChannelMetadataMustNotVetoDefinitiveViewerInEitherOrder() {
        for (viewerFirst in listOf(false, true)) {
            val tree = syntheticTree("com.google.android.youtube") {
                if (viewerFirst) node("com.google.android.youtube:id/reel_recycler")
                node("com.google.android.youtube:id/channel_title")
                if (!viewerFirst) node("com.google.android.youtube:id/reel_recycler")
            }
            assertTrue(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun genericEditableNodeDoesNotVetoViewerButFocusedEditorDoes() {
        for (focused in listOf(false, true)) {
            val tree = syntheticTree("com.google.android.youtube") {
                node("com.google.android.youtube:id/player_view") {
                    node("com.google.android.youtube:id/reel_recycler")
                    node(className = "android.widget.EditText", isEditable = true, isFocused = focused)
                }
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertEquals(!focused, result.isMatch)
            if (focused) assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, result.suppressionReason)
        }
    }

    @Test
    fun hiddenOffscreenAndShelfSizedViewerIdsDoNotMatch() {
        for ((visible, bounds) in listOf(
            false to intArrayOf(0, 0, 1080, 2400),
            true to intArrayOf(0, 2500, 1080, 4900),
            true to intArrayOf(0, 500, 1080, 1200)
        )) {
            val tree = syntheticTree("com.google.android.youtube") {
                node("com.google.android.youtube:id/reel_recycler",
                    isVisibleToUser = visible, bounds = bounds)
            }
            assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun hiddenBackgroundSuppressionDoesNotVetoViewerFallback() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/search_edit_text", isVisibleToUser = false)
            node(contentDescription = "Shorts player")
        }
        assertTrue(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun foregroundSearchAndChannelKeepSmallShortsPreviewsUsable() {
        for (context in listOf("search_edit_text", "channel_header", "watch_while_layout")) {
            val tree = syntheticTree("com.google.android.youtube") {
                node("com.google.android.youtube:id/$context")
                node("com.google.android.youtube:id/reel_video", bounds = intArrayOf(0, 500, 1080, 1200))
            }
            assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun weakViewerDescriptionDoesNotOverrideStandardVideoSuppression() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/watch_while_layout") {
                node(contentDescription = "Shorts player")
            }
        }
        assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun wrongPackageAndHiddenRootCannotMatchEvenWithViewerId() {
        val wrong = syntheticTree("another.app") {
            node("com.google.android.youtube:id/reel_recycler")
        }
        assertFalse(detector.evaluate(wrong, traversalEngine = traversalEngine).isMatch)
        wrong.packageName = "com.google.android.youtube"
        wrong.isVisibleToUser = false
        assertFalse(detector.evaluate(wrong, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun suppressionCollectionStillHonorsTraversalBudget() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/watch_while_layout") {
                repeat(170) { node(className = "android.view.View") }
                node("com.google.android.youtube:id/reel_recycler")
            }
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse(result.isMatch)
        assertEquals(150, result.stats.nodesEvaluated)
        assertTrue(result.stats.budgetExhausted)
    }

    private lateinit var detector: YouTubeDetector
    private lateinit var traversalEngine: TraversalEngine

    @Before
    fun setUp() {
        detector = YouTubeDetector()
        traversalEngine = TraversalEngine(maxDepth = 12, maxBudget = 150)
    }

    @Test
    fun testYouTubeShortsPrimaryRecyclerMatchesDefinitive() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/shorts_container") {
                node("com.google.android.youtube:id/reel_recycler") {
                    node("com.google.android.youtube:id/reel_video")
                }
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue("Shorts recycler must match", result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals(DetectionLayer.PRIMARY_RESOURCE_ID, result.layerMatched)
    }

    @Test
    fun testYouTubeShortsPivotButtonDoesNotMatch() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/pivot_bar") {
                node(
                    "com.google.android.youtube:id/pivot_bar_shorts_button",
                    contentDescription = "Shorts",
                    bounds = intArrayOf(440, 2200, 640, 2350)
                )
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Shorts tab button must NOT block the app", result.isMatch)
    }

    @Test
    fun testYouTubeHomeShelfDoesNotMatch() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/shorts_shelf_cell")
            node(
                "com.google.android.youtube:id/pivot_bar_shorts_button",
                contentDescription = "Shorts",
                bounds = intArrayOf(440, 2200, 640, 2350)
            )
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Shorts shelf must NOT block the home feed", result.isMatch)
    }

    @Test
    fun testYouTubeShortsAllPrimaryIdsMatchDefinitive() {
        val primaryIds = listOf(
            "com.google.android.youtube:id/reel_player_view",
            "com.google.android.youtube:id/reel_player_page_view",
            "com.google.android.youtube:id/reel_swipe_layout"
        )

        for (id in primaryIds) {
            val tree = syntheticTree("com.google.android.youtube") {
                node(id)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for $id", result.isMatch)
            assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        }
    }

    @Test
    fun testYouTubeFallbackRegexMatchesHigh() {
        val fallbackIds = listOf(
            "com.google.android.youtube:id/reel_player_header",
            "com.google.android.youtube:id/shorts_player_overlay",
            "com.google.android.youtube:id/reel_player_overlay"
        )

        for (id in fallbackIds) {
            val tree = syntheticTree("com.google.android.youtube") {
                node(id)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for fallback id $id", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.FALLBACK_REGEX_ID, result.layerMatched)
        }
    }

    @Test
    fun testYouTubeMultilingualContentDescriptionsMatchHigh() {
        val descriptions = mapOf(
            "EN" to "Shorts player",
            "ES" to "Reproductor de Shorts",
            "FR" to "Lecteur Shorts",
            "DE" to "Shorts-Player",
            "PT" to "Player de Shorts",
            "AR" to "مشغل الفيديوهات القصيرة",
            "HI" to "शॉर्ट्स प्लेयर",
            "JA" to "ショートプレーヤー",
            "KO" to "Shorts 플레이어",
            "ID" to "Pemutar Shorts"
        )

        for ((lang, desc) in descriptions) {
            val tree = syntheticTree("com.google.android.youtube") {
                node(contentDescription = desc)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for $lang: $desc", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.CONTENT_DESCRIPTION, result.layerMatched)
        }
    }

    @Test
    fun testYouTubeStandardVideoWithScrubberSuppressesBlocking() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/watch_while_layout") {
                node("com.google.android.youtube:id/player_view")
                node("com.google.android.youtube:id/time_bar_current_time", text = "14:20 / 45:10")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Standard 16:9 player must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, result.suppressionReason)
    }

    @Test
    fun testYouTubeChannelHeaderSuppressesBlocking() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/channel_header") {
                node("com.google.android.youtube:id/channel_title", text = "Science Channel")
                node("com.google.android.youtube:id/subscriber_count", text = "2.5M Subscribers")
                node(text = "Shorts") // Shorts tab in channel page
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Channel header browsing must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.PROFILE_HEADER_DETECTED, result.suppressionReason)
    }

    @Test
    fun testYouTubeLongVideoWithShortsSuggestionsDoesNotMatch() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/watch_while_layout") {
                node("com.google.android.youtube:id/player_view")
                node(text = "Shorts")
                node(contentDescription = "Shorts")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Long-form playback must NOT be blocked", result.isMatch)
    }

    @Test
    fun testYouTubeCommentComposerSuppressesBlocking() {
        val tree = syntheticTree("com.google.android.youtube") {
            node("com.google.android.youtube:id/comment_composer") {
                node(className = "android.widget.EditText", text = "Great point in this video!")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Comment editing must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, result.suppressionReason)
    }
}
