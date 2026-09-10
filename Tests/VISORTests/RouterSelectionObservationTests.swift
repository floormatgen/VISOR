import Foundation
import Observation
import os
import SwiftUI
import Testing
import VISOR
import VISORObservation
import VISORTesting

// MARK: - RouterSelectionObservationTests

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct RouterSelectionObservationTests {
  @Test
  func `A new Router exposes a stable nil selection source`() {
    // Given
    let router = Router<TestScene>()

    // When
    let first = router.selectedRootValues
    let second = router.selectedRootValues

    // Then
    #expect(first.currentSnapshot() == nil)
    #expect(router.selectedRoot == nil)
    #expect(first._visorIdentity == second._visorIdentity)
  }

  @Test(arguments: TestRoot.allCases)
  func `Preview selection is available in the source baseline`(_ root: TestRoot) async throws {
    // Given
    let router = Router<TestScene>.preview(root: root)

    // When
    let values = router.selectedRootValues.makeAsyncIterator()
    let baseline = try await values.next()

    // Then
    #expect(baseline == .some(root))
    #expect(router.selectedRootValues.currentSnapshot() == root)
  }

  @Test
  func `SwiftUI binding writes preserve Apple Observation and publish synchronously`() {
    // Given
    let router = Router<TestScene>.preview(root: .home)
    let source = router.selectedRootValues
    let changes = OSAllocatedUnfairLock(initialState: 0)
    withObservationTracking {
      _ = router.selectedRoot
    } onChange: {
      changes.withLock { $0 += 1 }
    }
    @Bindable var bindableRouter = router

    // When
    $bindableRouter.selectedRoot.wrappedValue = .settings

    // Then
    #expect(changes.withLock { $0 } == 1)
    #expect(router.selectedRoot == .settings)
    #expect(source.currentSnapshot() == .settings)
  }

  @Test
  func `Iteration distinguishes a cleared selection from sequence completion`() async throws {
    // Given
    let router = Router<TestScene>()
    let values = router.selectedRootValues.makeAsyncIterator()

    // When
    let baseline = try await values.next()

    // Then
    #expect(baseline == .some(nil))

    // When
    router.selectedRoot = .home

    // Then
    #expect(try await values.next() == .some(.home))

    // When
    router.selectedRoot = nil

    // Then
    #expect(try await values.next() == .some(nil))
    #expect(router.selectedRootValues.currentSnapshot() == nil)
  }

  @Test
  func `Repeated assignments remain observable revisions`() async throws {
    // Given
    let router = Router<TestScene>.preview(root: .home)
    let values = router.selectedRootValues.makeAsyncIterator()
    let changes = OSAllocatedUnfairLock(initialState: 0)
    withObservationTracking {
      _ = router.selectedRoot
    } onChange: {
      changes.withLock { $0 += 1 }
    }

    // When
    let baseline = try await values.next()

    // Then
    #expect(baseline == .some(.home))

    // When
    router.selectedRoot = .home

    // Then
    #expect(try await values.next() == .some(.home))
    #expect(changes.withLock { $0 } == 0)

    // When
    router.selectedRoot = .settings

    // Then
    #expect(try await values.next() == .some(.settings))
    #expect(changes.withLock { $0 } == 1)
  }

  @Test
  func `Busy consumers receive the latest selection without replaying intermediate roots`() async throws {
    // Given
    let router = Router<TestScene>()
    let values = router.selectedRootValues.makeAsyncIterator()

    // When
    let baseline = try await values.next()

    // Then
    #expect(baseline == .some(nil))

    // When
    router.selectedRoot = .home
    router.selectedRoot = nil
    router.selectedRoot = .settings

    // Then
    #expect(try await values.next() == .some(.settings))
  }

  @Test
  func `Selection from a descendant publishes only on the tree root`() {
    // Given
    let root = Router<TestScene>.preview(root: .home)
    let child = root.childRouter(for: .home)
    let grandchild = child.childRouter()
    let source = root.selectedRootValues

    // When
    grandchild.select(root: .settings)

    // Then
    #expect(source.currentSnapshot() == .settings)
    #expect(child.selectedRootValues.currentSnapshot() == nil)
    #expect(grandchild.selectedRootValues.currentSnapshot() == nil)
  }

  @Test
  func `Direct child selection writes preserve node isolation`() {
    // Given
    let root = Router<TestScene>.preview(root: .home)
    let child = root.childRouter(for: .home)

    // When
    child.selectedRoot = .settings

    // Then
    #expect(child.selectedRootValues.currentSnapshot() == .settings)
    #expect(root.selectedRootValues.currentSnapshot() == .home)
  }

  @Test
  func `Selecting and pushing from a child publishes the root selection`() {
    // Given
    let root = Router<TestScene>.preview(root: .home)
    let child = root.childRouter(for: .home)
    let source = root.selectedRootValues

    // When
    child.selectAndPush(root: .settings, destination: .nested)

    // Then
    #expect(source.currentSnapshot() == .settings)
    #expect(root.childRouter(for: .settings).navigationPath == [.nested])
    #expect(child.selectedRootValues.currentSnapshot() == nil)
  }

  @Test
  func `Unified navigation publishes selection without requiring a mounted host`() {
    // Given
    let router = Router<TestScene>()
    let source = router.selectedRootValues

    // When
    let accepted = router.navigate(to: .root(.settings))

    // Then
    #expect(accepted)
    #expect(source.currentSnapshot() == .settings)
  }

  @Test
  func `Only an accepted deep link changes the selection source`() throws {
    // Given
    let router = Router<TestScene>.preview(root: .home)
    let source = router.selectedRootValues
    try router.configureDeepLinks(scheme: "test", parsers: [
      .matching(components: ["settings"], destination: .root(.settings))
    ])
    let url = try #require(URL(string: "test://settings"))

    // When
    let inactiveOutcome = router.openDeepLink(url)

    // Then
    #expect(inactiveOutcome == .inactive)
    #expect(source.currentSnapshot() == .home)

    // When
    router.activate()
    let acceptedOutcome = router.openDeepLink(url)

    // Then
    #expect(acceptedOutcome == .handled(.root(.settings)))
    #expect(source.currentSnapshot() == .settings)
  }

  @Test
  func `Bindings and reactions share the Router source and fence selection changes`() async throws {
    // Given
    let router = Router<TestScene>.preview(root: .home)
    let model = RouterSelectionObservationModel(router: router)

    // When
    try await observe(model) { test in
      // Then
      #expect(model.state.selectedRoot == .home)
      #expect(model.state.reactedRoot == .home)
      #expect(model.state.reactionCount == 1)
      #expect(router.selectedRootValues._visorActiveSubscriptionCount == 1)

      // When
      await test.perform { router.select(root: .settings) }

      // Then
      test.expect(\.selectedRoot, hasExactChanges: [.settings])
      test.expect(\.reactedRoot, hasExactChanges: [.settings])
      test.expect(\.reactionCount, hasExactChanges: [2])

      // When
      await test.perform { router.selectedRoot = nil }

      // Then
      test.expect(\.selectedRoot, hasExactChanges: [nil])
      test.expect(\.reactedRoot, hasExactChanges: [nil])
      test.expect(\.reactionCount, hasExactChanges: [3])
    }
    #expect(router.selectedRootValues._visorActiveSubscriptionCount == 0)
  }

  @Test
  func `Retaining a selection source does not retain its Router`() throws {
    // Given
    var router: Router<TestScene>? = .preview(root: .settings)
    weak let releasedRouter = router
    let source = try #require(router).selectedRootValues

    // When
    router = nil

    // Then
    #expect(releasedRouter == nil)
    #expect(source.currentSnapshot() == .settings)
  }
}
