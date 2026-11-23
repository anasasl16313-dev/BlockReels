package com.blockreels.app.detection

import com.blockreels.app.model.SyntheticNode
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.*
import org.junit.Test

/** Synthetic behavioral regressions for researched signatures; not device captures. */
class SelectiveVideoBlockingTest {
    @Test fun visibleViewersRemainReachableInDeepAndPartlyHiddenHierarchies() {
        val registry = DetectorRegistry()
        for ((pkg, id) in mapOf(
            "com.instagram.android" to "clips_viewer_view_pager",
            "com.google.android.youtube" to "reel_recycler",
            "com.facebook.katana" to "reels_viewer_root",
            "com.facebook.lite" to "reels_screen",
            "com.zhiliaoapp.musically" to "main_feed_container"
        )) {
            val detector = registry.getDetectorForPackage(pkg)!!
            val failures = mutableListOf<String>()
            for (deep in listOf(false, true)) {
                val root = syntheticTree(pkg)
                val hidden = SyntheticNode(isVisibleToUser = false)
                root.addChild(hidden)
                if (!deep) repeat(160) { hidden.addChild(SyntheticNode()) }
                var parent = SyntheticNode()
                root.addChild(parent)
                if (deep) repeat(16) {
                    val wrapper = SyntheticNode()
                    parent.addChild(wrapper)
                    parent = wrapper
                }
                val player = SyntheticNode(viewIdResourceName = "$pkg:id/$id")
                hidden.addChild(SyntheticNode(viewIdResourceName = player.viewIdResourceName))
                assertFalse("$pkg hidden viewer", detector.evaluate(root).isMatch)
                parent.addChild(player)
                val result = detector.evaluate(root)
                if (!result.isMatch) failures.add("deep=$deep ${result.stats}")
                player.bounds = intArrayOf(0, 500, 1080, 950)
                assertFalse("$pkg preview", detector.evaluate(root).isMatch)
            }
            assertTrue("$pkg missed $failures", failures.isEmpty())
        }
    }

    @Test fun instagramStoriesAreAllowedEvenWhenAViewerIsRetainedBehindThem() {
        val pkg = "com.instagram.android"
        val root = syntheticTree(pkg) {
            node("$pkg:id/clips_viewer_view_pager")
            node("$pkg:id/reel_viewer_tall_story_container")
        }
        val result = InstagramDetector().evaluate(root)
        assertFalse(result.isMatch)
        assertTrue(result.foregroundSuppressionConfirmed)
    }

    @Test fun insetInstagramAndYouTubeViewersMatchWithoutBlockingTheirPreviews() {
        for ((pkg, id) in listOf("com.instagram.android" to "clips_viewer_view_pager",
            "com.google.android.youtube" to "reel_recycler")) {
            val detector = DetectorRegistry().getDetectorForPackage(pkg)!!
            val viewer = syntheticTree(pkg) {
                node("$pkg:id/$id", bounds = intArrayOf(0, 180, 1080, 2100))
            }
            assertTrue(detector.evaluate(viewer).isMatch)
            val preview = syntheticTree(pkg) {
                node("$pkg:id/$id", bounds = intArrayOf(0, 600, 1080, 1250))
            }
            assertFalse(detector.evaluate(preview).isMatch)
        }
    }

    @Test fun offscreenParentsCannotMakeTheirVisibleChildrenLookLikeActiveViewers() {
        for ((pkg, id) in listOf("com.instagram.android" to "clips_viewer_view_pager",
            "com.google.android.youtube" to "reel_recycler",
            "com.facebook.katana" to "reels_viewer_root")) {
            val root = syntheticTree(pkg) {
                node(bounds = intArrayOf(1080, 0, 2160, 2400)) { node("$pkg:id/$id") }
            }
            assertFalse(DetectorRegistry().getDetectorForPackage(pkg)!!.evaluate(root).isMatch)
        }
    }

    @Test fun instagramFullReelOpenedFromFeedIsDistinctFromAnInlinePreview() {
        val pkg = "com.instagram.android"
        val root = syntheticTree(pkg) {
            node("$pkg:id/feed_recycler_view") {
                node("$pkg:id/clips_viewer_view_pager", bounds = intArrayOf(0, 150, 1080, 2200))
            }
        }
        assertTrue(InstagramDetector().evaluate(root).isMatch)
    }

    @Test fun modernTikTokFeedNeedsAVideoInTheSameVisibleViewerAcrossRegionalPackages() {
        val detector = TikTokDetector()
        for (pkg in detector.targetPackages) {
            for (hiddenVideo in listOf(false, true)) {
                val root = syntheticTree(pkg) {
                    node("$pkg:id/view_pager_layout_wrapper", bounds = intArrayOf(0, 100, 1080, 2100)) {
                        node("$pkg:id/long_press_layout", isVisibleToUser = !hiddenVideo)
                        node("$pkg:id/user_avatar", bounds = intArrayOf(950, 1200, 1050, 1300))
                    }
                }
                assertTrue("$pkg hidden video=$hiddenVideo", detector.evaluate(root).isMatch)
            }
            val separateVideo = syntheticTree(pkg) {
                node("$pkg:id/view_pager_layout_wrapper")
                node("$pkg:id/long_press_layout")
            }
            assertFalse(detector.evaluate(separateVideo).isMatch)
            val preview = syntheticTree(pkg) {
                node("$pkg:id/view_pager_layout_wrapper", bounds = intArrayOf(0, 400, 1080, 1000)) {
                    node("$pkg:id/long_press_layout")
                }
            }
            assertFalse(detector.evaluate(preview).isMatch)
        }
    }

    @Test fun tiktokSearchInboxProfileAndCameraStayUsableWithARetainedFeed() {
        val detector = TikTokDetector()
        for (pkg in detector.targetPackages) {
            for (safe in listOf("im_chat_recycler", "search_input", "profile_header", "camera_surface")) {
                val root = syntheticTree(pkg) {
                    node("$pkg:id/view_pager_layout_wrapper") { node("$pkg:id/long_press_layout") }
                    node("$pkg:id/$safe")
                }
                val result = detector.evaluate(root)
                assertFalse("$pkg $safe", result.isMatch)
                assertTrue(result.foregroundSuppressionConfirmed)
            }
        }
        val wrong = syntheticTree("other.app") { node("com.zhiliaoapp.musically:id/main_feed_container") }
        assertFalse(detector.evaluate(wrong).isMatch)
    }

    @Test fun facebookDetailsSurfaceIsNotTheSmallReelsNavigationButton() {
        for (pkg in FacebookDetector().targetPackages) {
            val detector = DetectorRegistry().getDetectorForPackage(pkg)!!
            val viewer = syntheticTree(pkg) {
                node(contentDescription = "Reels tab details", bounds = intArrayOf(0, 180, 1080, 2200))
            }
            assertTrue(detector.evaluate(viewer).isMatch)
            val feed = syntheticTree(pkg) {
                node("$pkg:id/news_feed_stream") {
                    node("$pkg:id/video_player")
                    node(contentDescription = "Reels tab details", bounds = intArrayOf(800, 2200, 1000, 2350))
                }
            }
            assertFalse(detector.evaluate(feed).isMatch)
        }
    }

    @Test fun liteReelsAreSelectiveAndStoriesWinOverRetainedReels() {
        val pkg = AppPlatform.FACEBOOK_LITE_PACKAGE
        val detector = FacebookDetector()
        for (id in listOf("reels_screen", "reels_player", "video_player_reels")) {
            assertTrue(detector.evaluate(syntheticTree(pkg) { node("$pkg:id/$id") }).isMatch)
        }
        for (pkgName in detector.targetPackages) {
            val story = syntheticTree(pkgName) {
                node("$pkgName:id/reels_viewer_root")
                node("$pkgName:id/story_viewer_container")
            }
            val result = detector.evaluate(story)
            assertFalse(result.isMatch)
            assertEquals(SuppressionReason.STORY_VIEWER_ACTIVE, result.suppressionReason)
            assertTrue(result.foregroundSuppressionConfirmed)
            for (safe in listOf("video_player", "search_edit_text", "message_composer", "profile_header_container")) {
                assertFalse(detector.evaluate(syntheticTree(pkgName) { node("$pkgName:id/$safe") }).isMatch)
            }
        }
    }
}
