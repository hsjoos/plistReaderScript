#!/usr/bin/swift

//  main.swift
//  plistBundle
//
//  Created by Herwart Schmidt-Joos
//

import Foundation

// MARK: - plist output formatter

var indentSpace = ""
let indentCharacter = " "
let indentString = String(repeating: indentCharacter, count: 4)

let separatorCharacter = "-"
var separatorString = String(repeating: separatorCharacter, count: 45)

let scriptSourceDefaultPath = "./"

let printflag_swiftType             = PrintFlag.on
let printflag_objectClassType       = PrintFlag.on
let printflag_ObjectClassTypeName   = PrintFlag.on
let printflag_separator             = PrintFlag.on

enum PrintFlag {
    case on
    case off

    var isOn: Bool {
        switch self {
        case .on:
            return true
        case .off:
            return false
        }
    }
}

enum ItemType: String {
    case array = "Array<Any>"
    case dictionary = "Dictionary<String, Any>"
    case string = "String"
    case boolean = "Bool"
    case integer = "Int"
    case double = "Double"
    case data = "Data"
    case date = "Date"
}

func printWithIndent(_ info: String, toggle: PrintFlag = .on) {
    if toggle.isOn {
        print("\(indentSpace)\(info)")
    }
}

// MARK: - get property types

/// Collect  item type from NSObject plist element and return respective Swift type
/// - Parameter item: dictionary element
/// - Returns: Swift type
func getItemType(itemValue: Any) -> [String: Any] {
    var plistElementType: Any
    let valueWithObjectType = itemValue as! NSObject
    let typeID = CFGetTypeID(valueWithObjectType)

    switch typeID {
    case CFBooleanGetTypeID():
        plistElementType = Bool.self
    case CFDictionaryGetTypeID():
        plistElementType = Dictionary<String, Any>.self
    case CFArrayGetTypeID():
        plistElementType = Array<Any>.self
    case CFDataGetTypeID():
        plistElementType = Data.self
    case CFDateGetTypeID():
        plistElementType = Date.self
    case CFStringGetTypeID():
        plistElementType = String.self
    case CFNumberGetTypeID():
        let valueWithNumberObjectType = itemValue as! NSNumber
        if CFNumberIsFloatType(valueWithNumberObjectType) {
            plistElementType = Double.self
        } else {
            plistElementType = Int.self
        }
    default:
        plistElementType = Any.self
    }
    return [
        "SwiftType": plistElementType.self, "ObjectType": typeID,
        "ObjectClassName": String(describing: type(of: itemValue)),
    ]
}

// MARK: - Read sample property list file and deserialize its elements into a dictionary collection

/// File manager will fetch plist file from compiled commandline tool as well as from swift script
/// - Parameter name: plist file name
/// - Returns: plist as dictionary
func getPlist(withName name: String) -> [String: Any]? {
    var path: String?
    let fullPath = name
    let fileType = ".plist"
    var fileName = (fullPath as NSString).lastPathComponent
    let directoryPath = (fullPath as NSString).deletingLastPathComponent
    if fileName.hasSuffix(fileType) {
        fileName = fileName.split(separator: ".").dropLast().joined(separator: ".")
    }
    #if SWIFT_PACKAGE
        if directoryPath.isEmpty {
            if let bundlePath: String = Bundle.module.path(
                forResource: fileName, ofType: fileType)
            {
                path = bundlePath
            }
        } else {
            path = directoryPath + "/\(fileName)" + fileType
        }
    #else
        if directoryPath.isEmpty {
            path = scriptSourceDefaultPath + "\(fileName)" + fileType
        } else {
            path = directoryPath + "/\(fileName)" + fileType
        }
    #endif
    if let plistData = FileManager.default.contents(atPath: path ?? "") {
        do {
            // Deserialize the property list
            let plistDictionary = try PropertyListSerialization.propertyList(
                from: plistData, options: .mutableContainersAndLeaves, format: nil)
            return plistDictionary as? [String: Any]
        } catch {
            print("Deserialization error occurred: \(error)")
        }
    }
    return nil
}

/// Print nested elements and display the hierarchical structure if collections in turn contain collections
/// - Parameter data:
func getItemInfo(data: [String: Any], insideCollectionType: ItemType) {

    enum Indent {
        case addSpace
        case reduceSpace
    }

    func adaptIndentation(_ adapt: Indent) {
        switch adapt {
        case .addSpace:
            indentSpace = indentSpace + indentString
            separatorString.removeLast(indentString.count)
        case .reduceSpace:
            indentSpace.removeFirst(indentString.count)
            separatorString.append(
                String(repeating: separatorCharacter, count: indentString.count))
        }
    }

    func printItemInfo(item: [String: Any]) {

        let currentSwiftItemType = ItemType(
            rawValue: (String(describing: item["SwiftType"] ?? "")))
        printWithIndent(
            "Object class TypeID: \(item["ObjectType"] ?? "")",
            toggle: printflag_objectClassType)
        printWithIndent(
            "Object class Name: \(item["ObjectClassName"] ?? "")",
            toggle: printflag_ObjectClassTypeName
        )
        if insideCollectionType == .dictionary {
            printWithIndent("key: \(item["key"] ?? "")")
        }
        if ![.dictionary, .array].contains(currentSwiftItemType) {
            printWithIndent("value: \(item["value"] ?? "")")
        }
        printWithIndent("Swift Type: \(currentSwiftItemType?.rawValue ?? "")", toggle: printflag_swiftType)
    }

    for item in data {
        var resultDictionary = getItemType(itemValue: item.value)
        guard let swiftType = resultDictionary["SwiftType"].self else {
            fatalError("type exception !!!")
        }
        let typeName = String(describing: swiftType)
        let resultKey = item.key
        let resultValue = item.value
        resultDictionary["key"] = resultKey
        resultDictionary["value"] = resultValue

        printWithIndent(separatorString, toggle: printflag_separator)

        switch ItemType(rawValue: typeName) {
        case .boolean:
            resultDictionary["value"] = resultValue as! Bool
            printItemInfo(item: resultDictionary)
        case .integer:
            resultDictionary["value"] = resultValue as! Int
            printItemInfo(item: resultDictionary)
        case .string:
            resultDictionary["value"] = resultValue as! String
            printItemInfo(item: resultDictionary)
        case .double:
            resultDictionary["value"] = resultValue as! Double
            printItemInfo(item: resultDictionary)
        case .date:
            resultDictionary["value"] = resultValue as! Date
            printItemInfo(item: resultDictionary)
        case .data:
            resultDictionary["value"] = resultValue as! Data
            printItemInfo(item: resultDictionary)
        case .dictionary:
            resultDictionary["value"] = resultValue as! [String: Any]
            printItemInfo(item: resultDictionary)
            adaptIndentation(.addSpace)
            getItemInfo(
                data: item.value as! [String: Any],
                insideCollectionType: .dictionary)
            adaptIndentation(.reduceSpace)
        case .array:
            resultDictionary["value"] = resultValue as! [Any]
            printItemInfo(item: resultDictionary)
            adaptIndentation(.addSpace)
            for arrayElement in item.value as! [Any] {
                let resultDictionary = getItemType(itemValue: arrayElement)
                guard let swiftType = resultDictionary["SwiftType"].self else {
                    fatalError("type exception !!!")
                }
                let swiftTypeName = String(describing: swiftType)
                let arrayItem = [swiftTypeName: arrayElement]
                getItemInfo(data: arrayItem, insideCollectionType: .array)
            }
            adaptIndentation(.reduceSpace)
        default:
            print("Error! type \(typeName) not found")
        }
    }
}

// Default file is "collections.plist"
var plistName = "collections"
if CommandLine.argc > 1 {
    plistName = CommandLine.arguments[1]
}
if let data: [String: Any] = getPlist(withName: plistName) {
    getItemInfo(data: data, insideCollectionType: .dictionary)
} else {
    print("no \(plistName).plist file found")
}
