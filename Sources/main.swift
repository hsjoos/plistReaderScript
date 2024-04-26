#!/usr/bin/swift

//  main.swift
//  plistBundle
//
//  Created by Herwart Schmidt-Joos
//

import Foundation

// MARK: - plist formatter

var indentSpace = ""
let indentValue = "    "
let scriptSourceDefaultPath = "./"

let printflag_swiftType           = PrintFlag.on
let printflag_objectClassType     = PrintFlag.on
let printflag_ObjectClassTypeName = PrintFlag.on
let printflag_separator           = PrintFlag.on

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

func printWithIndent(_ info: String, toggle: PrintFlag = .on) {
  if toggle.isOn {
    print("\(indentSpace)\(info)")
  }
}

// MARK: - get property types

/// Collect  item type from NSObject plist element and return respective Swift type
/// - Parameter item: dictionary element
/// - Returns: Swift type
func getCollectionType<T>(item: Any, valueWithType: T) -> T {
  var plistElementType: Any
  let valueWithObjectType = valueWithType as! NSObject
  let typeID = CFGetTypeID(valueWithObjectType)

  switch typeID {
  case CFBooleanGetTypeID():
    printWithIndent("Swift Bool", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_swiftType)
    plistElementType = Bool.self
  case CFDictionaryGetTypeID():
    printWithIndent("Swift Dictionary", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
    plistElementType = Dictionary<String, Any>.self
  case CFArrayGetTypeID():
    printWithIndent("Swift Array", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
    plistElementType = Array<Any>.self
  case CFDataGetTypeID():
    printWithIndent("Swift Data", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
    plistElementType = Data.self
  case CFDateGetTypeID():
    printWithIndent("Swift Date", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
    plistElementType = Date.self
  case CFStringGetTypeID():
    printWithIndent("Swift String", toggle: printflag_swiftType)
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
    plistElementType = String.self
  case CFNumberGetTypeID():
    let valueWithNumberObjectType = valueWithType as! NSNumber
    if CFNumberIsFloatType(valueWithNumberObjectType) {
      plistElementType = Double.self
      printWithIndent("Swift Double:", toggle: printflag_objectClassType)
    } else {
      plistElementType = Int.self
      printWithIndent("Swift Integer:", toggle: printflag_objectClassType)
    }
    printWithIndent("Object class TypeID: \(typeID)", toggle: printflag_objectClassType)
  default:
    plistElementType = Any.self
    printWithIndent("Object class TypeID-default: \(typeID)", toggle: printflag_objectClassType)
  }
  return plistElementType.self as! T
}

/// Create Collection Type
/// - Parameters:
///   - item: deserialized plist item as Core Foundation dictionary
///   - collectionType: collection type dictionary object
///   - genericElementValue: generic element value
/// - Returns: item key, value and type as dictionary
func collectionType<CollectionType>(
  of item: Any, collectionType: CollectionType, genericElementValue: Any
) -> CollectionType {
  let typeAsString = String(describing: type(of: genericElementValue))
  let collectionType = getCollectionType(item: item, valueWithType: genericElementValue)
  var elementValue = genericElementValue
  printWithIndent("Object class type name: \(typeAsString)", toggle: printflag_ObjectClassTypeName)

  if case let adaptedBoolElementValue as Bool = genericElementValue {
    elementValue = adaptedBoolElementValue
  }
  if let element = item as? Dictionary<String, Any>.Element {
    return ["key": element.key, "value": elementValue, "type": collectionType] as! CollectionType
  }
  return [String(describing: collectionType)] as! CollectionType
}

// MARK: - Read sample property list file and deserialize its elements into a dictionary collection

/// File manager will fetch plist file from compiled commandline tool as well as from swift script
/// - Parameter name: plist file name
/// - Returns: plist ad generic dictionary
func getPlist(withName name: String) -> [String: Any]? {
  var path: String?
  var fileName = name
  let fileType = ".plist"

  if name.hasSuffix(fileType) {
    fileName = name.split(separator: ".").dropLast().joined(separator: ".")
  }

  #if SWIFT_PACKAGE
    if let bundlePath: String = Bundle.module.path(forResource: fileName, ofType: fileType) {
      path = bundlePath
    }
  #else
    path = scriptSourceDefaultPath + "\(fileName)" + fileType
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

func printItem(data: [String: Any]) {

  enum Indent {
    case addSpace
    case reduceSpace
  }

  func adaptIndentation(_ adapt: Indent) {
    switch adapt {
    case .addSpace:
      indentSpace = indentSpace + indentValue
    case .reduceSpace:
      indentSpace.removeFirst(indentValue.count)
    }
  }

  for item in data {
    let resultDictionary = collectionType(
      of: item, collectionType: [String: Any](), genericElementValue: item.value)

    guard let resultType = resultDictionary["type"].self else {
      fatalError("type exception !!!")
    }
    guard let resultKey = resultDictionary["key"].self else {
      fatalError("key exception !!!")
    }
    guard let resultValue = resultDictionary["value"].self else {
      fatalError("value exception !!!")
    }
    let typeName = String(describing: resultType)
    switch typeName {
    case "Bool", "Int", "String", "Double":
      printWithIndent("key: \(resultKey), type: \(typeName)")
      printWithIndent("value: \(resultValue), type: \(typeName)")
    case "Dictionary<String, Any>":
      printWithIndent("key: \(resultKey), type: \(typeName)")
      adaptIndentation(.addSpace)
      printItem(data: item.value as! [String: Any])
      adaptIndentation(.reduceSpace)
    case "Array<Any>":
      printWithIndent("key: \(resultKey), type: \(typeName)")
      adaptIndentation(.addSpace)
      for arrayElement in item.value as! [Any] {
        let typeArray = collectionType(
          of: arrayElement, collectionType: [Any](), genericElementValue: arrayElement.self)
        var elementValue = arrayElement
        if case let adaptedBoolElementValue as Bool = arrayElement {
          elementValue = adaptedBoolElementValue
        }
        let elementType = typeArray.first!
        printWithIndent("value: \(elementValue), type: \(elementType as! String)")
      }
      adaptIndentation(.reduceSpace)
    default:
      print("Error! type \(typeName) not found")
    }
    printWithIndent(
      "--------------------------------------------------", toggle: printflag_separator)
  }
}

// default is collection.plist file
var plistName = "collections"
if CommandLine.argc > 1 {
  plistName = CommandLine.arguments[1]
}
if let data: [String: Any] = getPlist(withName: plistName) {
  printItem(data: data)
} else {
  print("no \(plistName).plist file found")
}
