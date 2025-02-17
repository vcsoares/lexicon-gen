import LexiconGenKit

class NamespaceNode: Equatable {
    let name: String
    private(set) var children = [NamespaceNode]()
    weak var parent: NamespaceNode?

    init(name: String) {
        self.name = name
    }

    var isRoot: Bool {
        self == .root
    }

    var allNodes: [NamespaceNode] {
        var nodes = isRoot ? [] : [self]
        for child in children {
            nodes.append(contentsOf: child.allNodes)
        }

        return nodes
    }

    var namespace: String {
        var names = [String]()

        var target = self
        while let n = target.parent {
            names.append(n.name)
            target = n
        }
        names.reverse()

        return names.filter { !$0.isEmpty }.joined(separator: ".")
    }

    var fullName: String {
        [namespace, name].filter { !$0.isEmpty }.joined(separator: ".")
    }

    func addNode(names: [String]) {
        guard !names.isEmpty else {
            return
        }

        var names = names
        let name = names.removeFirst()

        let target: NamespaceNode
        if let child = children.first(where: { $0.name == name }) {
            target = child
        } else {
            let child = NamespaceNode(name: name)
            child.parent = self
            children.append(child)

            target = child
        }

        target.addNode(names: names)
    }

    static var root: NamespaceNode {
        NamespaceNode(name: "")
    }

    static func == (lhs: NamespaceNode, rhs: NamespaceNode) -> Bool {
        lhs.name == rhs.name
            && lhs.children.count == rhs.children.count
            && zip(lhs.children, rhs.children).allSatisfy { $0 == $1 }
            && lhs.parent == rhs.parent
    }
}

struct SwiftNamespaceDefinition {
    let parent: String
    let name: String

    var fullName: String {
        parent + "." + name
    }
}

struct SwiftDefinition<Object> {
    let id: LexiconDefinitionID
    let parent: String
    let name: String
    let object: Object

    var fullName: String {
        parent + "." + name
    }
}

class GenerateContext {
    private let docs = LexiconDocumentCollection<LexiconAbsoluteReference>()

    init() {}

    func append(_ doc: LexiconDocument<LexiconAbsoluteReference>) {
        docs.add(doc)
    }

    func generateNamespaceDefinitions() -> [SwiftNamespaceDefinition] {
        let defs = generateDefinitions()

        let rootNode = NamespaceNode.root
        for def in defs {
            rootNode.addNode(names: def.parent.components(separatedBy: "."))
        }

        let namespaces = Set(rootNode.allNodes.map(\.fullName).filter { !$0.isEmpty })
        let definitions = Set(defs.map(\.fullName))
        return namespaces.subtracting(definitions)
            .sorted()
            .compactMap { namespace in
                guard let (parent, name) = separateFullName(namespace) else {
                    return nil
                }

                return SwiftNamespaceDefinition(parent: parent, name: name)
            }
    }

    func generateDefinitions() -> [SwiftDefinition<LexiconSchema<LexiconAbsoluteReference>>] {
        docs.generateDefinitions()
            .sorted { $0.key.value < $1.key.value }
            .map { key, value in
                let (parent, name) = key.swiftDefinitionNames
                return SwiftDefinition(id: key, parent: parent, name: name, object: value)
            }
    }

    private func separateFullName(_ fullName: String) -> (parent: String, name: String)? {
        var components = fullName.components(separatedBy: ".")
        guard components.count >= 1 else {
            return nil
        }

        let name = components.removeLast()
        return (components.joined(separator: "."), name)
    }
}

internal extension LexiconDefinitionID {
    var swiftDefinitionNames: (parent: String, name: String) {
        var namespaceComponents = nsid.segments.map(\.headUppercased)
        if isMain {
            let name = namespaceComponents.popLast()!
            let parent = namespaceComponents.joined(separator: ".")
            return (parent, name)
        }

        return (
            namespaceComponents.joined(separator: "."),
            name.headUppercased
        )
    }
}

private extension String {
    var headUppercased: String {
        prefix(1).uppercased() + dropFirst()
    }
}
