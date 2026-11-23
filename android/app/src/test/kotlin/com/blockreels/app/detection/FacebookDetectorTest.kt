package com.blockreels.app.detection

import com.blockreels.app.engine.TraversalEngine
import com.blockreels.app.model.AccessibilityNode
import com.blockreels.app.model.SyntheticNode
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class FacebookDetectorTest {

    private val pkg = AppPlatform.FACEBOOK.packageName
    private lateinit var detector: FacebookDetector
    private lateinit var traversalEngine: TraversalEngine

    @Before
    fun setUp() {
        detector = FacebookDetector()
        traversalEngine = TraversalEngine(maxDepth = 12, maxBudget = 150)
    }

    @Test
    fun recognizesIdlessFacebookReelsViewerByItsScrollableVideoLayout() {
        val reelList = SyntheticNode(className = "androidx.recyclerview.widget.RecyclerView", isScrollable = true)
        val reelItem = SyntheticNode(className = "android.widget.Button", isLongClickable = true)
        val surface = SyntheticNode(className = "android.view.SurfaceView")
        val root = syntheticTree(pkg).addChild(reelList)
        reelList.addChild(reelItem.addChild(surface))
        assertEquals(DetectionLayer.CLASS_HIERARCHY, detector.evaluate(root).layerMatched)

        reelItem.isLongClickable = false
        assertFalse(detector.evaluate(root).isMatch)
        reelItem.isLongClickable = true
        reelItem.children.clear()
        reelList.addChild(surface)
        assertFalse("Signals on separate branches do not identify a viewer", detector.evaluate(root).isMatch)
    }

    @Test
    fun recognizesLegacyFacebookReelsComposerMarkerEvenWhenSmall() {
        val root = syntheticTree(pkg) {
            node(contentDescription = "FbShortsComposerAttachmentComponentSpec_GIF",
                bounds = intArrayOf(100, 2100, 160, 2160))
        }
        assertEquals(DetectionLayer.CONTENT_DESCRIPTION, detector.evaluate(root).layerMatched)
    }

    @Test
    fun liteReelsPlayerMustFillItsNonClickableContainerInALargeScrollingList() {
        val lite = AppPlatform.FACEBOOK_LITE_PACKAGE
        val root = syntheticTree(lite)
        val listBounds = intArrayOf(0, 240, 1080, 2320)
        val playerBounds = intArrayOf(0, 240, 1080, 2100)
        val list = SyntheticNode(className = "androidx.recyclerview.widget.RecyclerView",
            bounds = listBounds, isScrollable = true)
        val player = SyntheticNode(viewIdResourceName = "$lite:id/video_view", bounds = playerBounds)
        val parent = SyntheticNode(className = "android.view.ViewGroup", bounds = playerBounds)
        root.addChild(list.addChild(parent.addChild(player)))
        assertEquals(DetectionLayer.CLASS_HIERARCHY, detector.evaluate(root).layerMatched)

        parent.isClickable = true
        assertFalse("Inline feed video", detector.evaluate(root).isMatch)
        parent.isClickable = false
        parent.bounds = listBounds
        assertFalse("More videos card with room for controls", detector.evaluate(root).isMatch)
        parent.bounds = playerBounds
        list.isScrollable = false
        assertFalse("Story viewer or single video", detector.evaluate(root).isMatch)
        list.isScrollable = true
        player.isVisibleToUser = false
        assertFalse("Offscreen reel", detector.evaluate(root).isMatch)
    }

    @Test
    fun liteIndexedPlayerStillHasToPassTheSameLayoutChecks() {
        val lite = AppPlatform.FACEBOOK_LITE_PACKAGE
        val root = syntheticTree(lite)
        val list = SyntheticNode(className = "androidx.recyclerview.widget.RecyclerView", isScrollable = true)
        val parent = SyntheticNode(className = "android.view.ViewGroup")
        val player = SyntheticNode(viewIdResourceName = "$lite:id/video_view")
        root.addChild(list.addChild(parent.addChild(player)))
        val indexedRoot = object : AccessibilityNode by root {
            override val childCount = 0
            override fun findByViewId(viewId: String): List<AccessibilityNode> {
                assertEquals(player.viewIdResourceName, viewId)
                return listOf(player)
            }
        }
        assertTrue(detector.evaluate(indexedRoot).isMatch)
        parent.isClickable = true
        assertFalse(detector.evaluate(indexedRoot).isMatch)
        parent.isClickable = false
        // Story evidence from the current tree takes precedence over the video layout.
        root.addChild(SyntheticNode(viewIdResourceName = "$lite:id/story_viewer"))
        assertFalse(detector.evaluate(root).isMatch)
    }

    @Test
    fun compactDetailsInsideVisibleViewerCanIdentifyBothFacebookApps() {
        for (packageName in detector.targetPackages) {
            for (label in listOf("Reels tab details", "تفاصيل علامة تبويب ريلز")) {
                val tree = syntheticTree(packageName) {
                    node("$packageName:id/comment_composer")
                    node(className = "com.facebook.litho.LithoView") {
                        node(contentDescription = label, bounds = intArrayOf(20, 140, 480, 190))
                    }
                }
                assertTrue("$packageName / $label", detector.evaluate(tree).isMatch)
                val inline = syntheticTree(packageName) {
                    node(className = "androidx.recyclerview.widget.RecyclerView",
                        bounds = intArrayOf(0, 400, 1080, 1000)) {
                        node(contentDescription = label, bounds = intArrayOf(20, 440, 480, 490))
                    }
                }
                assertFalse(detector.evaluate(inline).isMatch)
            }
        }
    }

    @Test
    fun selectedReelsTabCanBeRecognizedWithoutResourceIds() {
        for (packageName in detector.targetPackages) {
            val root = syntheticTree(packageName) { node("$packageName:id/news_feed_stream") }
            val tab = SyntheticNode(contentDescription = "Reels, tab",
                bounds = intArrayOf(800, 2200, 1040, 2350))
            root.addChild(tab)
            assertFalse(detector.evaluate(root).isMatch)
            tab.isSelected = true
            assertTrue(detector.evaluate(root).isMatch)
            root.addChild(SyntheticNode(viewIdResourceName = "$packageName:id/home_tab",
                isSelected = true, bounds = intArrayOf(20, 2200, 240, 2350)))
            assertFalse(detector.evaluate(root).isMatch)
        }
    }

    @Test
    fun testFacebookReelsRootMatchesDefinitive() {
        val tree = syntheticTree("com.facebook.katana") {
            node("com.facebook.katana:id/reels_viewer_root") {
                node("com.facebook.katana:id/fb_shorts_video_player")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue(result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals(DetectionLayer.PRIMARY_RESOURCE_ID, result.layerMatched)
    }

    @Test
    fun backgroundNewsFeedDoesNotStopTraversalInEitherOrder() {
        for (feedFirst in listOf(true, false)) {
            val tree = syntheticTree(pkg) {
                if (feedFirst) node("$pkg:id/news_feed_stream")
                node("$pkg:id/reels_viewer_root")
                if (!feedFirst) node("$pkg:id/news_feed_stream")
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
            assertTrue(result.isMatch)
            assertFalse(result.disambiguationSuppressed)
        }
        val wrappedViewer = syntheticTree(pkg) {
            node("$pkg:id/newsfeed_recycler_view") {
                node("$pkg:id/fb_shorts_viewer_container")
            }
        }
        assertTrue(detector.evaluate(wrappedViewer, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun standardFeedVideoAndReelsPromoStayUsable() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/news_feed_stream") {
                node("$pkg:id/video_player", className = "android.view.SurfaceView")
                node("$pkg:id/fb_shorts_video_player", bounds = intArrayOf(0, 400, 1080, 1050)) {
                    node(contentDescription = "Watch Reels", bounds = intArrayOf(30, 420, 330, 500))
                }
            }
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse(result.isMatch)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, result.suppressionReason)
    }

    @Test
    fun onlyFocusedChatOrEditorVetoesAnActiveViewer() {
        for (focused in listOf(false, true)) {
            val tree = syntheticTree(pkg) {
                node("$pkg:id/messages_list_view") {
                    node(className = "android.widget.TextView", isFocused = focused)
                }
                node("$pkg:id/reels_viewer_root")
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertEquals(!focused, result.isMatch)
            if (focused) assertEquals(SuppressionReason.CHAT_THREAD_CONTAINER, result.suppressionReason)
        }
        val editor = syntheticTree(pkg) {
            node("$pkg:id/reels_viewer_root") {
                node(className = "android.widget.EditText", isEditable = true, isFocused = true,
                    bounds = intArrayOf(20, 2100, 980, 2250))
            }
        }
        val result = detector.evaluate(editor, traversalEngine = traversalEngine)
        assertFalse(result.isMatch)
        assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, result.suppressionReason)
    }

    @Test
    fun profileAndUnscopedLabelsDoNotBlock() {
        val profile = syntheticTree(pkg) {
            node("$pkg:id/profile_header_container") { node(contentDescription = "Facebook Reels") }
        }
        val profileResult = detector.evaluate(profile, traversalEngine = traversalEngine)
        assertFalse(profileResult.isMatch)
        assertEquals(SuppressionReason.PROFILE_HEADER_DETECTED, profileResult.suppressionReason)
        val standalone = syntheticTree(pkg) { node(contentDescription = "Watch Reels") }
        assertFalse(detector.evaluate(standalone, traversalEngine = traversalEngine).isMatch)
    }

    @Test
    fun hiddenAndOffscreenViewersAndWrongPackagesDoNotMatch() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/reels_viewer_root", isVisibleToUser = false) {
                node("$pkg:id/fb_shorts_video_player")
            }
            node("$pkg:id/fb_shorts_viewer_container", bounds = intArrayOf(0, 2450, 1080, 4850))
        }
        assertFalse(detector.evaluate(tree, traversalEngine = traversalEngine).isMatch)
        for (other in listOf("com.facebook.orca", AppPlatform.FACEBOOK_LITE_PACKAGE)) {
            val wrongRoot = syntheticTree(other) { node("$pkg:id/reels_viewer_root") }
            assertFalse(detector.evaluate(wrongRoot, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun keepsTraversalBudgetWhenContinuingPastSuppression() {
        val tree = syntheticTree(pkg) {
            node("$pkg:id/news_feed_stream")
            repeat(150) { node(className = "android.view.View") }
            node("$pkg:id/reels_viewer_root")
        }
        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse(result.isMatch)
        assertEquals(150, result.stats.nodesEvaluated)
        assertTrue(result.stats.budgetExhausted)
    }

    @Test
    fun testFacebookReelsTabButtonDoesNotMatch() {
        val tree = syntheticTree("com.facebook.katana") {
            node(
                "com.facebook.katana:id/reels_tab_button",
                contentDescription = "Reels",
                bounds = intArrayOf(850, 2200, 1080, 2350)
            )
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Reels tab must NOT block the news feed", result.isMatch)
    }

    @Test
    fun testFacebookNewsfeedWithReelsTabDoesNotMatch() {
        val tree = syntheticTree("com.facebook.katana") {
            node("com.facebook.katana:id/newsfeed_recycler_view") {
                node(text = "Friend posted a photo")
            }
            node(
                "com.facebook.katana:id/reels_tab_button",
                contentDescription = "Reels",
                bounds = intArrayOf(850, 2200, 1080, 2350)
            )
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("News feed must NOT be blocked by the Reels tab", result.isMatch)
    }

    @Test
    fun testFacebookAllPrimaryIdsMatchDefinitive() {
        val primaryIds = listOf(
            "com.facebook.katana:id/fb_shorts_viewer_container",
            "com.facebook.katana:id/reel_viewer_surface_view",
            "com.facebook.katana:id/fb_shorts_video_player",
            "com.facebook.katana:id/reels_feed_view_pager"
        )

        for (id in primaryIds) {
            val tree = syntheticTree("com.facebook.katana") {
                node(id)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for $id", result.isMatch)
            assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        }
    }

    @Test
    fun narrowPrimaryControlsRequireViewerContext() {
        val controls = listOf("fb_shorts_bottom_sheet_container", "fb_shorts_ufi_container")
        for (control in controls) {
            val bounds = intArrayOf(800, 1400, 1040, 1600)
            val inViewer = syntheticTree(pkg) {
                node("$pkg:id/fb_shorts_viewer_overlay") {
                    node("$pkg:id/$control", bounds = bounds)
                }
            }
            val result = detector.evaluate(inViewer, traversalEngine = traversalEngine)
            assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
            assertEquals("$pkg:id/$control", result.matchedIdentifier)
            val standalone = syntheticTree(pkg) { node("$pkg:id/$control") }
            assertFalse(detector.evaluate(standalone, traversalEngine = traversalEngine).isMatch)
        }
    }

    @Test
    fun testFacebookFallbackRegexMatchesHigh() {
        val fallbackIds = listOf(
            "com.facebook.katana:id/fb_shorts_viewer_overlay",
            "com.facebook.katana:id/reel_viewer_control_panel",
            "com.facebook.katana:id/fb_reels_viewer_page"
        )

        for (id in fallbackIds) {
            val tree = syntheticTree("com.facebook.katana") {
                node(id)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for fallback id $id", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.FALLBACK_REGEX_ID, result.layerMatched)
        }
    }

    @Test
    fun testFacebookMultilingualDescriptionsMatchHigh() {
        val descriptions = mapOf(
            "EN" to "Facebook Reels",
            "ES" to "Ver Reels",
            "FR" to "Regarder des Reels",
            "DE" to "Reels ansehen",
            "PT" to "Assistir a Reels",
            "AR" to "مشاهدة مقاطع Reels",
            "HI" to "रील्स देखें",
            "JA" to "Facebookリール",
            "KO" to "Facebook 릴스",
            "ID" to "Tonton Reels"
        )

        for ((lang, desc) in descriptions) {
            val tree = syntheticTree(pkg) {
                node("$pkg:id/news_feed_stream")
                node(className = "android.widget.FrameLayout") {
                    node("$pkg:id/fb_shorts_viewer_container", bounds = intArrayOf(0, 250, 1080, 1800)) {
                        node(contentDescription = desc, bounds = intArrayOf(40, 1200, 340, 1250))
                    }
                }
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for $lang: $desc", result.isMatch)
            assertEquals(DetectionConfidence.HIGH, result.confidence)
            assertEquals(DetectionLayer.CONTENT_DESCRIPTION, result.layerMatched)
        }
    }

    @Test
    fun narrowMultilingualTextOnlyCountsInsideViewerBranch() {
        for (inside in listOf(false, true)) {
            val bounds = intArrayOf(40, 1200, 340, 1250)
            val tree = syntheticTree(pkg) {
                node("$pkg:id/reel_viewer_surface_view", bounds = intArrayOf(0, 250, 1080, 1800)) {
                    if (inside) node(text = "Ver Reels", bounds = bounds)
                }
                if (!inside) node(text = "Ver Reels", bounds = bounds)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertEquals(inside, result.isMatch)
            if (inside) assertEquals(DetectionLayer.MULTILINGUAL_TEXT, result.layerMatched)
        }
    }

    @Test
    fun testFacebookNewsfeedRecyclerSuppressesBlocking() {
        val tree = syntheticTree("com.facebook.katana") {
            node("com.facebook.katana:id/news_feed_stream") {
                node(text = "Friend posted a photo")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Newsfeed must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.STANDARD_FEED_SCRUBBER, result.suppressionReason)
    }

    @Test
    fun testFacebookMessengerComposerSuppressesBlocking() {
        val tree = syntheticTree("com.facebook.katana") {
            node("com.facebook.katana:id/message_composer") {
                node(className = "android.widget.EditText", text = "See you tomorrow!")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Message composer must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.CHAT_COMPOSER_ACTIVE, result.suppressionReason)
    }
}
