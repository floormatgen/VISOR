import RootGatewayModelsMainActor
import SwiftUI
import Testing
import VISOR

@Suite("Binding and effect API from a MainActor-default client", .timeLimit(.minutes(1)))
@MainActor
struct BindingAndEffectTests {

  // MARK: Internal

  @Test
  func `Public binding cases dispatch immediately through the model`() {
    // Given
    let model = MainActorBindingViewModel()
    let state = model.state
    let binding = model.bindings.isEnabled

    // When
    binding.wrappedValue = true
    binding.wrappedValue = false
    model.bindings.isEnabled.wrappedValue = true

    // Then
    #expect(model.state === state)
    #expect(model.handledValues == [true, false, true])
    #expect(state.isEnabled)
  }

  @Test
  func `Public effect handles include synchronous result delivery`() async throws {
    // Given
    let model = MainActorBindingViewModel()

    // When
    let handle: EffectHandle<Int> = model.prepare(42)
    let value = try await handle.value()

    // Then
    #expect(value == 42)
    #expect(model.state.preparedValue == 42)
  }

  @Test
  func `Serial and concurrent owners are usable across package boundaries`() async throws {
    // Given
    let queue = SerialEffectQueue(capacity: 2)
    let concurrent = ConcurrentEffects()

    // When
    let saved = queue.enqueue { "saved" }
    let independent = concurrent.run { 7 }
    await queue.finish()
    await concurrent.finish()

    // Then
    #expect(try await saved.value() == "saved")
    #expect(try await independent.value() == 7)
  }

  @Test
  func `LazyViewModel selector syntax compiles in a public view`() {
    // Given
    let view = MainActorBindingView()

    // Then
    requireView(view)
    requireView(view.body)
  }

  @Test
  func `Public computed bindings route actions across package boundaries`() {
    let model = MainActorBindingViewModel()
    let binding = model.bindings.isDisabled
    #expect(binding.wrappedValue)
    binding.wrappedValue = false
    binding.wrappedValue = false
    #expect(model.handledValues == [true, true])
    #expect(model.state.isEnabled)
    model.updateState(\.isEnabled, to: false)
    #expect(binding.wrappedValue)
    #expect(model.handledValues == [true, true])
  }

  @Test
  func `Typed namespaces support generic forwarding and unannotated stored writes`() {
    let model = MainActorBindingViewModel()
    let controls: ViewModelBindings<MainActorBindingViewModel> = bindings(for: model)
    controls.preparedValue.wrappedValue = 23
    #expect(model.state.preparedValue == 23)
    #expect(model.handledValues.isEmpty)

    // A retained copy still reaches the same model-owned action path.
    controls.isEnabled.wrappedValue = true
    #expect(model.handledValues == [true])
  }

  // MARK: Private

  private func bindings<Model: ViewModel>(for model: Model) -> Model.Bindings {
    model.bindings
  }

  private func requireView(_: some View) { }
}
