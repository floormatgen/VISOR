import SwiftDiagnostics
import SwiftSyntaxMacros
import Testing

#if canImport(VISORMacros)
import VISORMacros

@Suite("ViewModel finality contracts")
struct ViewModelFinalityMacroTests {
  @Test(arguments: [
    ("", ""),
    ("public ", "public "),
    ("open ", "public "),
  ])
  func `Non-final ViewModels are rejected without generating members or conformance`(
    modifiers: String,
    fixedModifiers: String,
  ) {
    assertMacroExpansionSwiftTesting(
      """
      @MainActor
      @Observable
      @ViewModel
      \(modifiers)class Model {
        public final class State {}
      }
      """,
      expandedSource: """
        @MainActor
        @Observable
        \(modifiers)class Model {
          public final class State {}
        }
        """,
      diagnostics: [
        DiagnosticSpec(
          id: MessageID(domain: "VISOR", id: "viewModelRequiresFinal"),
          message: "@ViewModel requires a final class; share behaviour through composition instead of inheritance",
          line: 4,
          column: modifiers.count + 7,
          severity: .error,
          fixIts: [FixItSpec(message: "make the ViewModel final")],
        )
      ],
      macros: ["ViewModel": ViewModelMacro.self],
      applyFixIts: ["make the ViewModel final"],
      fixedSource: """
        @MainActor
        @Observable
        @ViewModel
        \(fixedModifiers)final class Model {
          public final class State {}
        }
        """,
    )
  }
}
#endif
