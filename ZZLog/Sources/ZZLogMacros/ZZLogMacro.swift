import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ZZLogErrorMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
            _ = Task {
                await MainActor.run {
                    ZipZapLog.shared.error(\(argument))
                }
            }
        """
    }
}

public struct ZZLogWarnMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
            _ = Task {
                await MainActor.run {
                    ZipZapLog.shared.warn(\(argument))
                }
            }
        """
    }
}

public struct ZZLogInfoMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
            _ = Task {
                await MainActor.run {
                    ZipZapLog.shared.info(\(argument))
                }
            }
        """
    }
}

public struct ZZLogTraceMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
            _ = Task {
                await MainActor.run {
                    ZipZapLog.shared.trace(\(argument))
                }
            }
        """
    }
}

@main
struct ZZLogPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ZZLogErrorMacro.self,
        ZZLogWarnMacro.self,
        ZZLogInfoMacro.self,
        ZZLogTraceMacro.self
    ]
}
