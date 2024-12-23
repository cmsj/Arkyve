// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that handles logging for ZipZap
@freestanding(expression)
public macro ZZError(_ msg: String) = #externalMacro(module: "ZZLogMacros", type: "ZZLogErrorMacro")

@freestanding(expression)
public macro ZZWarn(_ msg: String) = #externalMacro(module: "ZZLogMacros", type: "ZZLogErrorMacro")

@freestanding(expression)
public macro ZZInfo(_ msg: String) = #externalMacro(module: "ZZLogMacros", type: "ZZLogErrorMacro")

@freestanding(expression)
public macro ZZTrace(_ msg: String) = #externalMacro(module: "ZZLogMacros", type: "ZZLogTraceMacro")
