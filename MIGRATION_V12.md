# Migrating to VISOR 12

VISOR 12 moves SwiftUI binding ownership from State to the ViewModel and adds
action bindings for get-only computed State properties. This is a major-version
change; do not adopt it as a source-compatible 11.x update.

## Replace the binding entry point

Keep existing `@StateBinding(\State.field)` annotations and synchronous handlers.
Change the control's binding expression:

```swift
// VISOR 11.1
Toggle("Enabled", isOn: viewModel.bindableState[\.isEnabled])
// Inside @LazyViewModel content:
Toggle("Enabled", isOn: bindableState[\.isEnabled])

// VISOR 12
Toggle("Enabled", isOn: viewModel.bindings.isEnabled)
// Inside @LazyViewModel content:
Toggle("Enabled", isOn: bindings.isEnabled)
```

The old `bindableState` convenience is removed. `bindings` is a generated,
model-owned `ViewModelBindings<Model>` namespace. It lazily retains one reference
root; accessing or copying it preserves that identity. Do not construct a new
`ViewModelBindings(model)` in a view body. Rename authored ViewModel members that
conflict with the generated `bindings` name. An authored view member named
`bindings` is preserved with a warning; use `viewModel.bindings` in that view.

## Audit raw State bindings

This is also a behavioural break: `state[\.field] = value` and
`Bindable(model.state)[\.field].wrappedValue = value` still compile for stored
fields, but now **always commit directly**, even when the field has a
`@StateBinding` action. They never dispatch an action or require connection.

Migrate every control that relies on validation, normalisation, persistence or
other action behaviour to `model.bindings.field`. A binding for an unannotated
stored field commits through `updateState`; no action annotation is required
for genuinely local input.

Within handlers, keep `updateState(\.field, to: value)`. `@Bound` reconciliation,
Observation and stored-field mutation histories are unchanged. Never write an
annotated `bindings.field` inside its own handler—it would dispatch recursively.

## Bind derived values without duplicate State

```swift
// Inside State:
private(set) var activeSheet: Sheet?
var isPickerPresented: Bool { activeSheet == .picker }

// Inside Action:
@StateBinding(\State.isPickerPresented)
case pickerPresentationChanged(Bool)

// Inside handle(_:):
case .pickerPresentationChanged(let presented):
  guard !presented, state.activeSheet == .picker else { return }
  updateState(\.activeSheet, to: nil)

// Inside @LazyViewModel content:
.sheet(isPresented: bindings.isPickerPresented) { PickerContent() }
```

Computed properties must be synchronous, get-only, accessible, and declared
directly in State. Only annotated computed properties gain bindings. The handler
owns the meaning of a proposed write; VISOR generates no inverse setter or cache.
Reads preserve the authored getter's Observation dependencies.

Computed properties gain no State mutation selectors. Continue asserting
`\.activeSheet` with `hasExactChanges`; `updateState(\.isPickerPresented, ...)`
and strict mutation-history expectations for that computed property do not
compile. Nested value-type members are not made independently observable.

## Ownership and manual conformers

There is no connection phase. Authored initialisers and factories work identically.
State no longer stores action routes or enforces a single action owner. A retained
binding keeps State readable without retaining its ViewModel; after the model
deinitialises, binding writes do nothing. Each model dispatches its own actions,
even if models share a State instance.

`@ViewModel` generates the new `bindings`, `_VISORBindingSelectors` and
`_visorBindingSelectors` protocol requirements. The `Bindings` associated type
is inferred from the generated property; generic forwarding can return
`Model.Bindings`. Subclassable ViewModels remain supported. Hand-written `ViewModel`
conformers must implement them and retain their `ViewModelBindings` value once.
The underscored binding route types, State route requirement and connection hook
from VISOR 11 are removed. Do not call or recreate them.

## Unchanged APIs

- `@StateBinding` still requires a synchronous, nonthrowing `handle(_:)`.
- Every proposed write dispatches immediately, including unchanged values.
- Handlers may reject, normalise or commit values; there is no initial action.
- Async handlers remain supported on models without action binding annotations.
- `LatestEffect`, `SerialEffectQueue`, `ConcurrentEffects` and their completion
  handles are unchanged. This migration does not redesign action completion.
- The four package products and deployment targets are unchanged.

Validate controls, rejected writes and stored-field histories after migration.
Hunch adoption is separate from the VISOR package change.
