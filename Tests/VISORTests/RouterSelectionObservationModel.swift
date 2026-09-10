import Observation
import VISOR

// MARK: - RouterSelectionObservationModel

@MainActor
@Observable
@ViewModel
final class RouterSelectionObservationModel {

  // MARK: Internal

  final class State {

    // MARK: Lifecycle

    init(selectedRoot: TestRoot?) {
      self.selectedRoot = selectedRoot
    }

    // MARK: Internal

    @Bound(source: \RouterSelectionObservationModel.router.selectedRootValues)
    private(set) var selectedRoot: TestRoot?

    private(set) var reactedRoot: TestRoot? = nil
    private(set) var reactionCount = 0
  }

  let router: Router<TestScene>

  // MARK: Private

  @Reaction(source: \RouterSelectionObservationModel.router.selectedRootValues)
  private func selectionChanged(_ root: TestRoot?) {
    updateState(\.reactedRoot, to: root)
    updateState(\.reactionCount, to: state.reactionCount + 1)
  }
}
