import SwiftSyntax

// MARK: - StateProjectionSpec

/// A synchronous, named, get-only property declared directly in State.
struct StateProjectionSpec {
  let name: String
  let accessPrefix: String
}

func stateProjectionSpec(from declaration: some DeclSyntaxProtocol) -> StateProjectionSpec? {
  guard
    let variable = declaration.as(VariableDeclSyntax.self),
    variable.bindingSpecifier.text == "var",
    !variable.modifiers.hasStateTypeStorageModifier,
    variable.modifiers.stateFieldAccessPrefix != "private ",
    variable.bindings.count == 1,
    let binding = variable.bindings.first,
    let identifier = binding.pattern.as(IdentifierPatternSyntax.self),
    !identifier.identifier.text.hasPrefix("_visor"),
    let accessorBlock = binding.accessorBlock
  else { return nil }

  switch accessorBlock.accessors {
  case .getter:
    break
  case .accessors(let accessors):
    guard
      accessors.count == 1,
      let accessor = accessors.first,
      accessor.accessorSpecifier.text == "get",
      accessor.effectSpecifiers == nil
    else { return nil }
  }

  return StateProjectionSpec(
    name: identifier.identifier.text,
    accessPrefix: variable.modifiers.stateFieldAccessPrefix,
  )
}
