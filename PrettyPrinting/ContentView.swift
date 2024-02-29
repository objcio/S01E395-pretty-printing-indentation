import SwiftUI

indirect enum Doc {
    case empty
    case text(String)
    case sequence(Doc, Doc)
    case newline
    case indent(Doc)
    case hang(Doc)
    case choice(Doc, Doc) // left is widest doc
}

struct PrettyState {
    var columnWidth: Int
    var stack: [(indentation: Int, Doc)]
    var tabWidth = 4
    var currentColumn = 0

    init(columnwidth: Int, doc: Doc) {
        self.columnWidth = columnwidth
        self.stack = [(0, doc)]
    }

    mutating func render() -> String {
        guard let (indentation, el) = stack.popLast() else { return "" }
        switch el {
        case .empty:
            return "" + render()
        case .text(let string):
            currentColumn += string.count
            return string + render()
        case .sequence(let doc, let doc2):
            stack.append((indentation, doc2))
            stack.append((indentation, doc))
            return render()
        case .newline:
            currentColumn = indentation
            return "\n" + String(repeating: " ", count: indentation) + render()
        case .indent(let doc):
            stack.append((indentation + tabWidth, doc))
            return render()
        case .hang(let doc):
            stack.append((currentColumn, doc))
            return render()
        case .choice(let doc, let doc2):
            let copy = self
            stack.append((indentation, doc))
            let attempt = render()
            if attempt.fits(width: columnWidth-copy.currentColumn) {
                return attempt
            } else {
                self = copy
                stack.append((indentation, doc2))
                return render()
            }
        }
    }
}

extension String {
    func fits(width: Int) -> Bool {
        prefix { !$0.isNewline }.count <= width
    }
}

extension Doc {
    func flatten() -> Doc {
        switch self {
        case .empty:
            .empty
        case .text(_):
            self
        case .sequence(let doc, let doc2):
            .sequence(doc.flatten(), doc2.flatten())
        case .newline:
            .text(" ")
        case .indent(let doc):
            .indent(doc.flatten())
        case .hang(let doc):
            .hang(doc.flatten())
        case .choice(let doc, _):
            doc
        }
    }

    func group() -> Doc {
        .choice(flatten(), self)
    }
}


extension Doc {
    func pretty(columns: Int) -> String {
        var state = PrettyState(columnwidth: columns, doc: self)
        return state.render()
    }

    static func +(lhs: Doc, rhs: Doc) -> Doc {
        .sequence(lhs, rhs)
    }
}

extension Array where Element == Doc {
    func joined(separator: Doc) -> Doc {
        guard let f = first else { return .empty }
        return dropFirst().reduce(f) { $0 + separator + $1 }
    }
}

extension Doc: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        assert(!value.contains("\n"))
        self = .text(value)
    }
}

func parameters(_ params: [Doc]) -> Doc {
    let joined = params.joined(separator: "," + .newline).group()
    return .choice(.hang(joined), .indent(.newline + joined) + .newline)
}

let arguments = parameters([
    .text("proposal: ProposedViewSize"),
    .text("subviews: Subviews"),
    .text("cache: inout ()")
])

let doc: Doc = .text("func hello(") + arguments + .text(") {") + .indent(.newline + .text("print(\"Hello\")")) + .newline + .text("}")

struct ContentView: View {
    @State var width = 20.0
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                Text(String(repeating: ".", count: Int(width)))
                Text(doc.pretty(columns: Int(width)))
                    .fixedSize()
            }
            Spacer()
            Slider(value: $width, in: 0...120)
        }
        .monospaced()
        .padding()
    }
}

#Preview {
    ContentView()
}
