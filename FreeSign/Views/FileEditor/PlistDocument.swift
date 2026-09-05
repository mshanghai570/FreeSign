import Foundation
import SwiftUI

// MARK: - PlistNodeValue

/// Typed representation of any plist value, including nested containers.
indirect enum PlistNodeValue: Equatable {
    case string(String)
    case integer(Int)
    case real(Double)
    case boolean(Bool)
    case date(Date)
    case data(Data)
    case array([PlistNode])
    case dictionary([PlistNode])   // each child's .key is non-nil

    // MARK: Type metadata

    var typeName: String {
        switch self {
        case .string:     return "String"
        case .integer:    return "Integer"
        case .real:       return "Real"
        case .boolean:    return "Boolean"
        case .date:       return "Date"
        case .data:       return "Data"
        case .array:      return "Array"
        case .dictionary: return "Dictionary"
        }
    }

    /// Compact label used in the type badge chip.
    var typeShort: String {
        switch self {
        case .string:     return "Str"
        case .integer:    return "Int"
        case .real:       return "Real"
        case .boolean:    return "Bool"
        case .date:       return "Date"
        case .data:       return "Data"
        case .array:      return "Array"
        case .dictionary: return "Dict"
        }
    }

    var typeColor: Color {
        switch self {
        case .string:     return Color(hex: "#4A90D9")   // blue
        case .integer:    return Color(hex: "#E67E22")   // orange
        case .real:       return Color(hex: "#E67E22")   // orange
        case .boolean:    return Color(hex: "#27AE60")   // green
        case .date:       return Color(hex: "#9B59B6")   // purple
        case .data:       return Color(hex: "#7F8C8D")   // slate
        case .array:      return Color(hex: "#B87333")   // bronze
        case .dictionary: return Color(hex: "#C9A84C")   // gold
        }
    }

    var isContainer: Bool {
        switch self { case .array, .dictionary: return true; default: return false }
    }

    var children: [PlistNode]? {
        switch self {
        case .array(let c), .dictionary(let c): return c
        default:                                return nil
        }
    }

    var childCount: Int? { children?.count }

    var valuePreview: String {
        switch self {
        case .string(let s):
            return s.isEmpty ? "(empty)" : s
        case .integer(let i):
            return "\(i)"
        case .real(let r):
            return String(format: "%g", r)
        case .boolean(let b):
            return b ? "true" : "false"
        case .date(let d):
            return d.formatted(date: .abbreviated, time: .shortened)
        case .data(let d):
            return "\(d.count) byte\(d.count == 1 ? "" : "s")"
        case .array(let a):
            return "\(a.count) item\(a.count == 1 ? "" : "s")"
        case .dictionary(let d):
            return "\(d.count) key\(d.count == 1 ? "" : "s")"
        }
    }

    // MARK: Serialization

    func toPropertyListObject() -> Any {
        switch self {
        case .string(let s):   return s
        case .integer(let i):  return i
        case .real(let r):     return r
        case .boolean(let b):  return b
        case .date(let d):     return d
        case .data(let d):     return d
        case .array(let nodes):
            return nodes.map { $0.value.toPropertyListObject() }
        case .dictionary(let nodes):
            return nodes.reduce(into: [String: Any]()) { dict, node in
                if let k = node.key { dict[k] = node.value.toPropertyListObject() }
            }
        }
    }

    // MARK: Parsing

    /// Converts an `Any` from NSDictionary/NSArray into a typed PlistNodeValue.
    /// Bool MUST be checked before Int — NSNumber bridges both, requiring CFTypeID.
    static func from(_ any: Any) -> PlistNodeValue {
        if let num = any as? NSNumber,
           CFGetTypeID(num as CFTypeRef) == CFBooleanGetTypeID() {
            return .boolean(num.boolValue)
        }
        switch any {
        case let s  as String:      return .string(s)
        case let i  as Int:         return .integer(i)
        case let r  as Double:      return .real(r)
        case let r  as Float:       return .real(Double(r))
        case let d  as Date:        return .date(d)
        case let d  as Data:        return .data(d)
        case let arr as [Any]:
            return .array(arr.enumerated().map {
                PlistNode(key: nil, value: .from($0.element))
            })
        case let dict as [String: Any]:
            let nodes = dict
                .map { PlistNode(key: $0.key, value: .from($0.value)) }
                .sorted { ($0.key ?? "") < ($1.key ?? "") }
            return .dictionary(nodes)
        default:
            return .string("\(any)")
        }
    }

    static func == (lhs: PlistNodeValue, rhs: PlistNodeValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a),  .string(let b)):  return a == b
        case (.integer(let a), .integer(let b)): return a == b
        case (.real(let a),    .real(let b)):    return a == b
        case (.boolean(let a), .boolean(let b)): return a == b
        case (.data(let a),    .data(let b)):    return a == b
        case (.date(let a),    .date(let b)):    return a == b
        default:                                  return false
        }
    }
}

// MARK: - PlistNode

struct PlistNode: Identifiable, Equatable {
    var id: UUID = UUID()
    var key: String?          // dict key; nil for array elements
    var value: PlistNodeValue

    init(key: String? = nil, value: PlistNodeValue) {
        self.key = key
        self.value = value
    }

    static func == (lhs: PlistNode, rhs: PlistNode) -> Bool { lhs.id == rhs.id }
}

// MARK: - PlistDocument

/// Owns the full plist tree and provides ID-based mutation API.
/// Views observe this object and use its methods to make changes.
final class PlistDocument: ObservableObject {

    @Published private(set) var rootNodes: [PlistNode] = []
    private(set) var plistPath: String = ""
    private(set) var isArrayRoot: Bool = false

    // MARK: Init

    init() {}   // empty doc for error-state fallback

    init(plistPath: String) throws {
        self.plistPath = plistPath
        try load()
    }

    func load() throws {
        let url = URL(fileURLWithPath: plistPath)
        guard let raw = try? PropertyListSerialization.propertyList(
            from: Data(contentsOf: url), options: [], format: nil
        ) else { throw PlistDocumentError.loadFailed }

        if let dict = raw as? [String: Any] {
            isArrayRoot = false
            rootNodes = dict
                .map { PlistNode(key: $0.key, value: PlistNodeValue.from($0.value)) }
                .sorted { ($0.key ?? "") < ($1.key ?? "") }
        } else if let arr = raw as? [Any] {
            isArrayRoot = true
            rootNodes = arr.enumerated().map {
                PlistNode(key: nil, value: PlistNodeValue.from($0.element))
            }
        } else {
            throw PlistDocumentError.loadFailed
        }
    }

    // MARK: - Query

    func children(ofNodeID id: UUID) -> [PlistNode] {
        findNode(id: id, in: rootNodes)?.value.children ?? []
    }

    func isArrayContainer(id: UUID) -> Bool {
        guard let node = findNode(id: id, in: rootNodes) else { return false }
        if case .array = node.value { return true }
        return false
    }

    // MARK: - Mutations

    func updateValue(_ newValue: PlistNodeValue, forNodeID id: UUID) {
        rootNodes = mutate(id: id, in: rootNodes) { n in var m = n; m.value = newValue; return m }
        save()
    }

    func updateKey(_ newKey: String, forNodeID id: UUID) {
        rootNodes = mutate(id: id, in: rootNodes) { n in var m = n; m.key = newKey; return m }
        save()
    }

    func deleteNode(id: UUID) {
        rootNodes = deleteRecursive(id: id, from: rootNodes)
        save()
    }

    func addNode(_ node: PlistNode, toContainerID containerID: UUID?) {
        if let cid = containerID {
            rootNodes = addToContainer(node, cid: cid, in: rootNodes)
        } else {
            rootNodes.append(node)
            if !isArrayRoot { rootNodes.sort { ($0.key ?? "") < ($1.key ?? "") } }
        }
        save()
    }

    func moveNodes(source: IndexSet, destination: Int, inContainerID containerID: UUID?) {
        if let cid = containerID {
            rootNodes = moveInContainer(source: source, dest: destination, cid: cid, in: rootNodes)
        } else {
            rootNodes.move(fromOffsets: source, toOffset: destination)
        }
        save()
    }

    // MARK: - Raw XML

    func rawXML() -> String {
        let obj: Any = isArrayRoot
            ? rootNodes.map { $0.value.toPropertyListObject() }
            : rootNodes.reduce(into: [String: Any]()) { r, n in if let k = n.key { r[k] = n.value.toPropertyListObject() } }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: obj, format: .xml, options: 0)
        else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func applyRawXML(_ xml: String) {
        guard let data = xml.data(using: .utf8),
              let obj = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil)
        else { return }
        if let dict = obj as? [String: Any] {
            rootNodes = dict
                .map { PlistNode(key: $0.key, value: PlistNodeValue.from($0.value)) }
                .sorted { ($0.key ?? "") < ($1.key ?? "") }
        } else if let arr = obj as? [Any] {
            rootNodes = arr.enumerated().map { PlistNode(key: nil, value: PlistNodeValue.from($0.element)) }
        }
        save()
    }

    // MARK: - Save

    func save() {
        guard !plistPath.isEmpty else { return }
        let obj: Any = isArrayRoot
            ? rootNodes.map { $0.value.toPropertyListObject() }
            : rootNodes.reduce(into: [String: Any]()) { r, n in if let k = n.key { r[k] = n.value.toPropertyListObject() } }
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: obj, format: .xml, options: 0)
        else { return }
        try? data.write(to: URL(fileURLWithPath: plistPath), options: .atomic)
    }

    // MARK: - Private Recursion

    private func findNode(id: UUID, in nodes: [PlistNode]) -> PlistNode? {
        for node in nodes {
            if node.id == id { return node }
            if let c = node.value.children, let found = findNode(id: id, in: c) { return found }
        }
        return nil
    }

    private func mutate(id: UUID, in nodes: [PlistNode], _ t: (PlistNode) -> PlistNode) -> [PlistNode] {
        nodes.map { node in
            if node.id == id { return t(node) }
            switch node.value {
            case .dictionary(let c): var n = node; n.value = .dictionary(mutate(id: id, in: c, t)); return n
            case .array(let c):      var n = node; n.value = .array(mutate(id: id, in: c, t));      return n
            default: return node
            }
        }
    }

    private func deleteRecursive(id: UUID, from nodes: [PlistNode]) -> [PlistNode] {
        nodes
            .filter { $0.id != id }
            .map { node in
                switch node.value {
                case .dictionary(let c): var n = node; n.value = .dictionary(deleteRecursive(id: id, from: c)); return n
                case .array(let c):      var n = node; n.value = .array(deleteRecursive(id: id, from: c));      return n
                default: return node
                }
            }
    }

    private func addToContainer(_ new: PlistNode, cid: UUID, in nodes: [PlistNode]) -> [PlistNode] {
        nodes.map { node in
            if node.id == cid {
                var n = node
                switch node.value {
                case .dictionary(var c):
                    c.append(new); c.sort { ($0.key ?? "") < ($1.key ?? "") }
                    n.value = .dictionary(c)
                case .array(var c):
                    c.append(new)
                    n.value = .array(c)
                default: break
                }
                return n
            }
            switch node.value {
            case .dictionary(let c): var n = node; n.value = .dictionary(addToContainer(new, cid: cid, in: c)); return n
            case .array(let c):      var n = node; n.value = .array(addToContainer(new, cid: cid, in: c));      return n
            default: return node
            }
        }
    }

    private func moveInContainer(source: IndexSet, dest: Int, cid: UUID, in nodes: [PlistNode]) -> [PlistNode] {
        nodes.map { node in
            if node.id == cid {
                var n = node
                if case .array(var c) = node.value {
                    c.move(fromOffsets: source, toOffset: dest)
                    n.value = .array(c)
                }
                return n
            }
            switch node.value {
            case .dictionary(let c): var n = node; n.value = .dictionary(moveInContainer(source: source, dest: dest, cid: cid, in: c)); return n
            case .array(let c):      var n = node; n.value = .array(moveInContainer(source: source, dest: dest, cid: cid, in: c));      return n
            default: return node
            }
        }
    }
}

// MARK: - Errors

enum PlistDocumentError: LocalizedError {
    case loadFailed
    var errorDescription: String? { "Could not parse the plist file." }
}
