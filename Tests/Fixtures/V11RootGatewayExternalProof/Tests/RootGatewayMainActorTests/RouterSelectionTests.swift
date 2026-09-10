import SwiftUI
import Testing
import VISOR
import VISORObservation

// MARK: - RouterSelectionTests

@Suite(.timeLimit(.minutes(1)))
struct RouterSelectionTests {

  // MARK: Internal

  @Test
  func `Router selection is observable across the public package boundary`() async throws {
    // Given
    let router = Router<Scene>.preview(root: .home)
    let source = selectionSource(for: router)
    let values = source.makeAsyncIterator()
    @Bindable var bindableRouter = router

    // When
    let baseline = try await values.next()

    // Then
    #expect(baseline == .some(.home))

    // When
    $bindableRouter.selectedRoot.wrappedValue = .settings

    // Then
    #expect(source.currentSnapshot() == .settings)
    #expect(try await values.next() == .some(.settings))

    // When
    router.selectedRoot = nil

    // Then
    #expect(source.currentSnapshot() == nil)
    #expect(try await values.next() == .some(nil))
  }

  // MARK: Private

  private nonisolated enum Scene: NavigationScene {
    nonisolated enum Push: PushDestination {
      case detail
    }

    nonisolated enum Root: RootDestination {
      case home
      case settings
    }
  }

  /// A source can be obtained and read without inheriting the Router's actor.
  private nonisolated func selectionSource(
    for router: Router<Scene>
  ) -> ObservationSource<Scene.Root?> {
    router.selectedRootValues
  }
}
