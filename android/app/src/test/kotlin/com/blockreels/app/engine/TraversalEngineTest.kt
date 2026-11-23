package com.blockreels.app.engine

import com.blockreels.app.model.SyntheticNode
import com.blockreels.app.model.syntheticTree
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TraversalEngineTest {

    @Test
    fun diagnosticIndicesPreserveParentRelationshipsInBreadthFirstOrder() {
        val root = SyntheticNode().addChild(SyntheticNode().addChild(SyntheticNode()))
            .addChild(SyntheticNode())
        val links = mutableListOf<Pair<Int, Int?>>()
        val stats = TraversalEngine().traverse(root,
            diagnosticVisitor = { _, _, index, parent -> links.add(index to parent) }) { _, _ -> false }
        assertEquals(listOf(0 to null, 1 to 0, 2 to 0, 3 to 1), links)
        assertEquals(4, stats.nodesEvaluated)
    }

    @Test
    fun testTraversalDepthLimitCapsRecursionAt12Levels() {
        val engine = TraversalEngine(maxDepth = 12, maxBudget = 150)

        // Build a 20-level deep single-chain tree
        var current = syntheticTree("com.instagram.android", viewId = "level_0")
        val root = current
        for (i in 1..20) {
            val next = SyntheticNode(viewIdResourceName = "level_$i")
            current.addChild(next)
            current = next
        }

        var visitedCount = 0
        val stats = engine.traverse(root) { _, depth ->
            visitedCount++
            assertFalse("Depth must not exceed 12", depth > 12)
            false
        }

        assertEquals(13, stats.nodesEvaluated) // Root (0) + 12 children
        assertEquals(12, stats.maxDepthReached)
        assertTrue(stats.depthLimitReached)
        assertFalse(stats.budgetExhausted)
    }

    @Test
    fun testTraversalNodeBudgetCapsAt150Nodes() {
        val engine = TraversalEngine(maxDepth = 12, maxBudget = 150)

        // Build a wide tree with 300 leaf nodes
        val root = syntheticTree("com.instagram.android", viewId = "root") {
            for (i in 1..300) {
                node(viewId = "child_$i")
            }
        }

        var diagnosticNodes = 0
        val stats = engine.traverse(root,
            diagnosticVisitor = { _, _, _, _ -> diagnosticNodes++ }) { _, _ -> false }
        assertEquals(150, stats.nodesEvaluated)
        assertEquals(150, diagnosticNodes)
        assertTrue(stats.budgetExhausted)
        assertFalse(stats.depthLimitReached)
    }

    @Test
    fun testEarlyExitHaltsTraversalImmediately() {
        val engine = TraversalEngine(maxDepth = 12, maxBudget = 150)

        val root = syntheticTree("com.instagram.android", viewId = "root") {
            node("target_node")
            for (i in 1..50) {
                node("after_target_$i")
            }
        }

        var targetFound = false
        val stats = engine.traverse(root) { node, _ ->
            if (node.viewIdResourceName == "target_node") {
                targetFound = true
                return@traverse true // Halt immediately
            }
            false
        }

        assertTrue(targetFound)
        assertTrue("Traversal should have stopped shortly after finding target, visited=${stats.nodesEvaluated}", stats.nodesEvaluated <= 3)
    }

    @Test
    fun testNullRootReturnsZeroStats() {
        val engine = TraversalEngine()
        val stats = engine.traverse(null) { _, _ -> false }
        assertEquals(0, stats.nodesEvaluated)
        assertEquals(0, stats.maxDepthReached)
    }
}
