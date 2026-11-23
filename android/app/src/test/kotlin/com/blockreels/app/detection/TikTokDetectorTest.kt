package com.blockreels.app.detection

import com.blockreels.app.engine.TraversalEngine
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class TikTokDetectorTest {

    private lateinit var detector: TikTokDetector
    private lateinit var traversalEngine: TraversalEngine

    @Before
    fun setUp() {
        detector = TikTokDetector()
        traversalEngine = TraversalEngine(maxDepth = 12, maxBudget = 150)
    }

    @Test
    fun testTikTokFeedContainerMatchesDefinitive() {
        val tree = syntheticTree("com.zhiliaoapp.musically") {
            node("com.zhiliaoapp.musically:id/root_view") {
                node("com.zhiliaoapp.musically:id/main_feed_container") {
                    node("com.zhiliaoapp.musically:id/viewpager")
                }
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertTrue(result.isMatch)
        assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        assertEquals(DetectionLayer.PRIMARY_RESOURCE_ID, result.layerMatched)
    }

    @Test
    fun testTikTokChatWithPagerIsStillSuppressed() {
        val tree = syntheticTree("com.zhiliaoapp.musically") {
            node("com.zhiliaoapp.musically:id/viewpager")
            node("com.zhiliaoapp.musically:id/chat_list") {
                node(className = "android.widget.EditText", text = "Hello")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Chat and inbox must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
    }

    @Test
    fun testTikTokRegionalChatIdsAreSuppressed() {
        val tree = syntheticTree("com.ss.android.ugc.trill") {
            node("com.ss.android.ugc.trill:id/viewpager")
            node("com.ss.android.ugc.trill:id/im_chat_recycler")
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Regional chat screen must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.CHAT_THREAD_CONTAINER, result.suppressionReason)
    }

    @Test
    fun testTikTokRegionalPackagesSupported() {
        val regionalPackages = listOf(
            "com.ss.android.ugc.trill",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.lite"
        )

        for (pkg in regionalPackages) {
            val tree = syntheticTree(pkg) {
                node("$pkg:id/vertical_viewpager")
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertTrue("Expected match for package $pkg", result.isMatch)
            assertEquals(DetectionConfidence.DEFINITIVE, result.confidence)
        }
    }

    @Test
    fun multilingualNavigationLabelsAloneNeverBlockTheApp() {
        val descriptions = mapOf(
            "EN" to "For You",
            "ES" to "Para ti",
            "FR" to "Pour toi",
            "DE" to "Für dich",
            "PT" to "Para Você",
            "AR" to "لك",
            "HI" to "आपके लिए",
            "JA" to "おすすめ",
            "KO" to "추천",
            "ID" to "Untuk Anda"
        )

        for ((lang, desc) in descriptions) {
            val tree = syntheticTree("com.zhiliaoapp.musically") {
                node(contentDescription = desc)
            }
            val result = detector.evaluate(tree, traversalEngine = traversalEngine)
            assertFalse("A $lang navigation label is not a video: $desc", result.isMatch)
        }
    }

    @Test
    fun testTikTokInboxAndChatSuppressesBlocking() {
        val tree = syntheticTree("com.zhiliaoapp.musically") {
            node("com.zhiliaoapp.musically:id/chat_list") {
                node("com.zhiliaoapp.musically:id/text_chat_input_box") {
                    node(className = "android.widget.EditText", text = "Hi there!")
                }
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Inbox/chat must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertTrue(
            "Expected a chat suppression reason",
            result.suppressionReason == SuppressionReason.CHAT_COMPOSER_ACTIVE ||
                result.suppressionReason == SuppressionReason.CHAT_THREAD_CONTAINER
        )
    }

    @Test
    fun testTikTokCreatorCameraSuppressesBlocking() {
        val tree = syntheticTree("com.zhiliaoapp.musically") {
            node("com.zhiliaoapp.musically:id/camera_surface")
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Creator camera must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.CREATOR_CAMERA_ACTIVE, result.suppressionReason)
    }

    @Test
    fun testTikTokProfileSuppressesBlocking() {
        val tree = syntheticTree("com.zhiliaoapp.musically") {
            node("com.zhiliaoapp.musically:id/profile_header") {
                node("com.zhiliaoapp.musically:id/following_count", text = "120")
            }
        }

        val result = detector.evaluate(tree, traversalEngine = traversalEngine)
        assertFalse("Profile tab must NOT be blocked", result.isMatch)
        assertTrue(result.disambiguationSuppressed)
        assertEquals(SuppressionReason.PROFILE_HEADER_DETECTED, result.suppressionReason)
    }
}
