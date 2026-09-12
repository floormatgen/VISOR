import SwiftDiagnostics
import SwiftSyntax

/// Generate typed descriptors without spelling or inferring the user's field
/// types. Swift infers them from State key paths, including initialiser-only
/// stored declarations. Forwarders never capture an instance or erase actions.
func viewModelBindingMembers(
  viewModel: ClassDeclSyntax,
  state: ClassDeclSyntax,
  bindings: [StateBindingSpec],
  accessPrefix: String,
) -> [DeclSyntax] {
  let model = viewModel.name.text
  let fields = state.memberBlock.members.compactMap {
    stateFieldSpec(from: $0.decl)
  }.filter { $0.accessPrefix != "private " }
  let projections = state.memberBlock.members.compactMap {
    stateProjectionSpec(from: $0.decl)
  }.filter { projection in bindings.contains { $0.fieldName == projection.name } }
  let selections = fields.map { ($0.name, $0.accessPrefix) } +
    projections.map { ($0.name, $0.accessPrefix) }
  var members: [DeclSyntax] = selections.map { name, _ in
    let write: String
    if let binding = bindings.first(where: { $0.fieldName == name }) {
      let argument = binding.label.map { "\($0): value" } ?? "value"
      write = "model.handle(.\(binding.caseName)(\(argument)))"
    } else {
      write = "model.updateState(\\.\(name), to: value)"
    }
    return DeclSyntax(stringLiteral: """
      private static let _visorBinding_\(name) = VISOR._ViewModelBinding(
        for: \(model).self,
        keyPath: \\State.\(name)
      ) { model, value in
        \(write)
      }
      """)
  }
  let selectors = selections.map { name, prefix in
    "\(prefix)let \(name) = \(model)._visorBinding_\(name)"
  }.joined(separator: "\n")
  members.append(contentsOf: [
    DeclSyntax(stringLiteral: """
      @MainActor
      \(accessPrefix)struct _VISORBindingSelectors {
        \(selectors)
        \(accessPrefix)init() {}
      }
      """),
    DeclSyntax(stringLiteral:
      "\(accessPrefix)static let _visorBindingSelectors = _VISORBindingSelectors()"),
    DeclSyntax(stringLiteral: """
      @ObservationIgnored
      private lazy var _visorBindings = VISOR.ViewModelBindings(self)
      """),
    DeclSyntax(stringLiteral: """
      \(accessPrefix)var bindings: VISOR.ViewModelBindings<\(model)> { _visorBindings }
      """),
  ])
  return members
}

// MARK: - BindingNamespaceDiagnostic

/// A focused diagnostic rather than a duplicate generated declaration.
struct BindingNamespaceDiagnostic: DiagnosticMessage {
  let macroName: String
  let name: String

  var message: String {
    "@\(macroName) could not generate '\(name)' because this type already declares that member; rename the existing member"
  }

  var diagnosticID: MessageID {
    MessageID(domain: "VISOR", id: "bindingNamespaceCollision")
  }

  var severity: DiagnosticSeverity {
    macroName == "LazyViewModel" ? .warning : .error
  }
}
