import Observation
import RootGatewayModelsNonisolated
import VISOR

#if VISOR_PROBE_NON_FINAL_MODEL
@MainActor
@Observable
@ViewModel
final class NonFinalViewModel {
  final class State { }
}
#endif

#if VISOR_PROBE_OPEN_MODEL
@MainActor
@Observable
@ViewModel
open class OpenViewModel {
  public final class State { }
}
#endif

#if VISOR_PROBE_MODEL_SUBCLASS
@MainActor
final class SubclassedViewModel: NonisolatedBindingViewModel { }
#endif
