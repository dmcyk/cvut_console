//
//  Console.swift
//  Task1
//
//  Created by Damian Malarczyk on 14.10.2016.
//  Copyright © 2016 Damian Malarczyk. All rights reserved.
//

import Foundation

public class HelpCommand: Command {
    private var commands: [Command]
    
    init(otherCommands: [Command]) {
        self.commands = otherCommands
    }
    
    public func printHelp() {
        print("Command: help")
        print("\tFormat: \n\t\t-someArgument=value\n\t\t--someOption[=optionalValue]\n\t\t--someFlag")
        print("\tFor array values use following:\n\t\t-someArgument=1,2,3,4\n")
        print("\tArguments are required to have values")
        print("\tOptions may either work only as flags, or as arguments with default values")
        print("\tUse --help flag with given command to see it's help\n\n")
        print("\tprinting help for all commands...\n")
        for cmd in commands {
            cmd.printHelp()
        }
    }
    public func run(data: CommandData) throws {
        printHelp()
    }

    public var parameters: [CommandParameter] = []

    public var name: String = "help"
    
}

public class Console {
    var arguments: [String]
    var commands: [Command]
    
    public init(arguments: [String], commands _commands: [Command], trimFirst: Bool = true) throws {
        var commands = _commands
        commands.append(HelpCommand(otherCommands: _commands))
        self.commands = commands
        
        if trimFirst {
            guard arguments.count > 1 else {
                throw CommandError.notEnoughArguments
            }
            self.arguments = Array(arguments.suffix(from: 1))
        } else {
            guard !arguments.isEmpty else {
                throw CommandError.notEnoughArguments
            }
            self.arguments = arguments
        }
    }
    
    public func run() throws {
        for cmd in commands {
            do {
                try cmd.parse(arguments: arguments)
                return
            } catch CommandError.incorrectCommandName {
            }
            
        }
        print("\(arguments[0]) is an incorrect command")
    }
}

public indirect enum ValueType: CustomStringConvertible {
    case int, double, string, array(ValueType)
    
    public var description: String {
        switch self {
        case .int:
            return "Int"
        case .double:
            return "Double"
        case .string:
            return "String"
        case .array(let type):
            return "Array<\(type.description)>"
        }
    }
}

public enum ValueError: Error {
    case noValue
}
public enum Value: CustomStringConvertible {
    case int(Int)
    case double(Double)
    case string(String)
    case array([Value])
    
    public func intValue() throws -> Int {
        if case .int(let value) = self {
            return value
        }
        throw ValueError.noValue
    }
    
    public func doubleValue() throws -> Double {
        if case .double(let value) = self {
            return value
        }
        throw ValueError.noValue
    }
    
    public func arrayValue() throws -> [Value] {
        if case .array(let value) = self {
            return value
        }
        throw ValueError.noValue
    }
    
    public func stringValue() throws -> String {
        if case .string(let val) = self {
            return val
        }
        throw ValueError.noValue
    }
    
    public var description: String {
        switch self {
        case .int(let val):
            return "Int(\(val))"
        case .double(let val):
            return "Double(\(val))"
        case .string(let val):
            return "String(\(val))"
        case .array(let val):
            return "Array(\(val.map { $0.description }.joined(separator: ",")))"
        }
    }
    
    
}

public enum ArgumentError: Error {
    case noAssignment, incorrectValue, indirectValue, noValue, wrongFormat //no equal sign
}

public struct ContainedArgumentError: Error {
    public let error: ArgumentError
    public let argument: Argument
    
    public init(error: ArgumentError, argument: Argument) {
        self.error = error
        self.argument = argument
    }
}

public protocol Command {
    var help: [String] { get }
    var name: String { get }
    var parameters: [CommandParameter] { get }
    
    func run(data: CommandData) throws
    func printHelp()

}

public extension Command {
    var help: [String] {
        return []
    }
    
    fileprivate func printParameters(_ parameters: [CommandParameter]) {
        for param in parameters {
            switch param {
            case .argument(let arg):
                print("\t-\(arg.name) Argument(\(arg.expected)) \(arg.description ?? "")")
            case .option(let opt):
                switch opt.mode {
                case .flag:
                    print("\t--\(opt.name) Flag \(opt.description ?? "")")
                case .value(let expected, let def):
                    print("\t--\(opt.name) Option(\(def != nil ? "\(def!)" : "\(expected)")) \(opt.description ?? "")")
                    
                }
            }
        }
    }
    
    func printHelp() {
        print("Command: \(name)")
        for line in help {
            print(line)
        }
        print()
        var options: [CommandParameter] = []
        var arguments: [CommandParameter] = []
        for p in parameters {
            switch p {
            case .argument(_):
                arguments.append(p)
            case .option(_):
                options.append(p)
            }
        }
        printParameters(arguments)
        if !options.isEmpty {
            print()
            printParameters(options)
        }
        print()
        
    }
    
    func parse(arguments: [String]) throws {
        guard !arguments.isEmpty, arguments[0] == name else {
            throw CommandError.incorrectCommandName
        }

        if Option("help", mode: .flag).flag(arguments) {
            printHelp()
            return
        }
        
        let data = try CommandData(parameters, input: Array(arguments.suffix(from: 1)))
        
        
        try run(data: data)
        
    }
}

public enum CommandError: Error {
    case parameterNameNotAllowed(String)
    case missingCommandArguments
    case notEnoughArguments
    case incorrectCommandName
}

public struct CommandData {
    private var arguments: [String: Argument]
    private var options: [String: Option]
    private var input: [String]
    
    public init(_ parameters: [CommandParameter], input: [String]) throws {
        arguments = [:]
        options = [:]
        self.input = input
        
        for param in parameters {
            switch param {
            case .argument(let arg):
                arguments[arg.name] = arg
                if input.filter({
                    $0.contains(arg.consoleName + "=")
                }).isEmpty  {
                    throw CommandError.missingCommandArguments
                }
            case .option(let opt):
                options[opt.name] = opt
            }
        }
    }
    
    
    public func value(_ argName: String) throws -> Value {
        guard let argument = arguments[argName] else {
            throw CommandError.parameterNameNotAllowed(argName)
        }
        return try argument.value(input)
        
    }
    
    public func flag(_ name: String) throws -> Bool {
        guard let option = options[name] else {
            throw CommandError.parameterNameNotAllowed(name)
        }
        return option.flag(input)
    }
    
    public func optionalValue(_ name: String) throws -> Value? {
        guard let option = options[name] else {
            throw CommandError.parameterNameNotAllowed(name)
        }
        return option.value(input)
    }
}

public enum CommandParameter {
    case option(Option)
    case argument(Argument)

}

public struct Option {
    public enum Mode {
        case flag
        case value(expected: ValueType, `default`: Value?)
    }
    
    public var name: String
    fileprivate var mode: Mode
    public var description: String? = nil
    

    public init(_ name: String, description: String? = nil, mode: Mode) {
        self.name = name
        self.description = description
        self.mode = mode
    }
    
    public func flag(_ input: [String]) -> Bool {
        
        if case .flag = mode {
            for i in input {
                if i == consoleName {
                    return true
                }
            }
        }
        
        return false
    }
    
    
    public func value(_ input: [String]) -> Value? {
        switch mode {
        case .flag:
            return nil
        case .value(let expected, let def):
            if let val = try? extractArgumentValue(input, nameFormat: consoleName, expected: expected, default: def) {
                return val
            }
            return def
           
        }
        
    }
}

public extension Option {
    var consoleName: String {
        return "--\(name)"
    }
}
public struct Argument {
    public var expected: ValueType
    public var name: String
    public var description: String? = nil
    
    public init(_ name: String, expectedValue: ValueType, description: String? = nil) {
        self.name = name
        self.description = description
        self.expected = expectedValue
    }
    
    public func value(_ input: [String]) throws -> Value {
        return try extractArgumentValue(input, nameFormat: consoleName, expected: expected, default: nil)
    }
}

public extension Argument {
    var consoleName: String {
        return "-\(name)"
    }
    
}

fileprivate func extractInt(_ src: String) throws -> Int {

    guard let number = Int(src) else {
        throw ArgumentError.incorrectValue
    }
    return number
}

fileprivate func extractDouble(_ src: String) throws -> Double {
    
    guard let number = Double(src) else {
        throw ArgumentError.incorrectValue
    }
    return number
}

fileprivate func extractArgumentValue(_ srcs: [String], nameFormat: String, expected: ValueType, default: Value?) throws -> Value {
    for src in srcs {
        
        if let equal = src.characters.index(of: "=") {
            guard src.substring(to: equal) == nameFormat else {
                continue
            }
        
            let afterEqual = src.characters.index(after: equal)
            let value = src.substring(from: afterEqual)
            
            switch expected {
            case .int:
                let number = try extractInt(value)
                return .int(number)
            case .double:
                let number = try extractDouble(value)
                return .double(number)
            case .string:
                return .string(value)
            case .array(let inner):
                let values = value.components(separatedBy: ",")
                switch inner {
                case .double:
                    return try .array(values.map {
                        try .double(extractDouble($0))
                    })
                case .int:
                    return try .array(values.map {
                        try .int(extractInt($0))
                    })
                case .string:
                    return .array(values.map {
                        .string($0)
                    })
                case .array(_):
                    throw ArgumentError.indirectValue
                }
            }
        }
        
    }
    
    if let def = `default` {
        return def
    } else {
        throw ArgumentError.noValue
    }
}
