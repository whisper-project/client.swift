// Copyright 2023 Daniel C Brotsky.  All rights reserved.
//
// All material in this project and repository is licensed under the
// GNU Affero General Public License v3. See the LICENSE file for details.

import Foundation

struct PastTextLine: Identifiable {
    var text: String
    var id: Int     // line number
}

final class PastTextViewModel: ObservableObject {
    @Published var pastText: [PastTextLine] = []
    
    init() {
    }
    
    init(initialText: String) {
        self.setFromText(initialText)
    }
    
    func getLines() -> [String] {
        return pastText.map({ $0.text })
    }
    
    func addLine(_ line: String) {
        pastText.append(PastTextLine(text: line, id: pastText.count))
    }
    
    func clearLines() {
        pastText.removeAll()
    }
    
    func setFromText(_ text: String) {
        pastText = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            pastText.append(PastTextLine(text: String(line), id: pastText.count))
        }
    }
    
    func getAsText() -> String {
        return pastText.map({ $0.text }).joined(separator: "\n")
    }
}