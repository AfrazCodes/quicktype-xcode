
import Foundation
import AppKit

import XcodeKit

typealias Invocation = XCSourceEditorCommandInvocation

class PasteJSONAsCodeCommand: NSObject, XCSourceEditorCommand {
    func error(_ message: String, details: String = "No details") -> NSError {
        return NSError(domain: "quicktype", code: 1, userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString(message, comment: ""),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString(details, comment: "")
            ])
    }
    
    func getFirstSelection(_ invocation: Invocation) -> XCSourceTextRange? {
        for range in invocation.buffer.selections {
            guard let range = range as? XCSourceTextRange else {
                continue
            }
            return range
        }
        return nil
    }
    
    func lineIsBlank(_ line: String) -> Bool {
        return line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func lineIsComment(_ line: String) -> Bool {
        return line.starts(with: "//")
    }
    
    func cleanGeneratedLines(_ lines: [String], _ invocation: Invocation) -> [String] {
        var cleaned = lines
        
        func isImportCommentOrEmpty(line: String) -> Bool {
            if lineIsComment(line) {
                return true
            }
            
            if line.starts(with: "import ") {
                return true
            }
            
            return lineIsBlank(line)
        }
        
        // Remove leading imports, comments, whitespace from start and end
        cleaned = Array(cleaned
            .drop(while: isImportCommentOrEmpty)
            .reversed().drop(while: isImportCommentOrEmpty).reversed()
        )
        
        return cleaned
    }
    
    func insertingAfterCode(_ buffer: XCSourceTextBuffer, _ selection: XCSourceTextRange) -> Bool {
        for i in 0..<selection.start.line {
            let line = buffer.lines[i] as! String
            if lineIsBlank(line) || lineIsComment(line) {
                continue
            }
            return true
        }
        return false
    }
    
    func handleSuccess(lines: [String], _ invocation: Invocation, _ completionHandler: @escaping (Error?) -> Void) {
        let buffer = invocation.buffer
        let selection = getFirstSelection(invocation) ?? XCSourceTextRange()
        
        // If we're pasting in the middle of anything, we omit imports
        let cleanLines = insertingAfterCode(buffer, selection)
         ? cleanGeneratedLines(lines, invocation)
         : lines
        
        let selectionEmpty =
            selection.start.line == selection.end.line &&
                selection.start.column == selection.end.column
        
        if !selectionEmpty {
            let selectedIndices = selection.end.line == buffer.lines.count
                ? selection.start.line...(selection.end.line - 1)
                : selection.start.line...selection.end.line
            
            buffer.lines.removeObjects(at: IndexSet(selectedIndices))
        }
        
        let insertedIndices = selection.start.line..<(selection.start.line + cleanLines.count)
        buffer.lines.insert(cleanLines, at: IndexSet(insertedIndices))
        
        // Clear any selections
        buffer.selections.removeAllObjects()
        let cursorPosition = XCSourceTextPosition(line: selection.start.line, column: 0)
        buffer.selections.add(XCSourceTextRange(start: cursorPosition, end: cursorPosition))
        
        completionHandler(nil)
    }
    
    func handleError(message: String, _ invocation: Invocation, _ completionHandler: @escaping (Error?) -> Void) {
        // Sometimes an error ruins our Runtime, so let's reinitialize it
        print("quicktype encountered an error: \(message)")
        if Runtime.shared.initialize() {
            print("quicktype runtime reinitialized")
        } else {
            print("quicktype runtime could not be reinitialized")
        }
        
        let displayMessage = message.contains("cannot parse input")
            ? "Clipboard does not contain valid JSON"
            : "quicktype encountered an internal error"
        
        completionHandler(error(displayMessage, details: message))
    }
    
    var renderTypesOnly: Bool {
        return false
    }
    
    func perform(with invocation: Invocation, completionHandler: @escaping (Error?) -> Void) -> Void {
        let runtime = Runtime.shared
        
        if !runtime.isInitialized && !runtime.initialize() {
            completionHandler(error("Couldn't initialize type engine"))
            return
        }
        
        guard let json = NSPasteboard.general.string(forType: .string) else {
            completionHandler(error("Couldn't get JSON from clipboard"))
            return
        }
        
        runtime.quicktype(json,
                          contentUTI: invocation.buffer.contentUTI as CFString,
                          justTypes: renderTypesOnly,
                          fail: { self.handleError(message: $0, invocation, completionHandler) },
                          success: { self.handleSuccess(lines: $0, invocation, completionHandler) })
    }
}
