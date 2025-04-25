import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct ZZLogErrorMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
        {
            let zzOutput = \(argument)
            _ = Task { @MainActor in
                    ArkyveLog.shared.error(zzOutput)
            }
        }()
        """
    }
}

struct ZZLogWarnMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
        {
            let zzOutput = \(argument)
            _ = Task { @MainActor in
                    ArkyveLog.shared.warn(zzOutput)
            }
        }()
        """
    }
}

struct ZZLogInfoMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
        {
            let zzOutput = \(argument)
            _ = Task { @MainActor in
                    ArkyveLog.shared.info(zzOutput)
            }
        }()
        """
    }
}

struct ZZLogTraceMacro: ExpressionMacro {
    public static func expansion(of node: some FreestandingMacroExpansionSyntax, in context: some MacroExpansionContext) throws -> ExprSyntax {
        guard let argument = node.arguments.first?.expression else {
            fatalError("compiler bug: the macro does not have any arguments")
        }

        return """
        {
            let zzOutput = \(argument)
            _ = Task { @MainActor in
                    ArkyveLog.shared.trace(zzOutput)
            }
        }()
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
