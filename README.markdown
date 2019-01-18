[![Build Status](https://travis-ci.org/catlan/LSPKit.svg?branch=master)](https://travis-ci.org/catlan/LSPKit)

# LSPKit - A Language Server Protocol implementations for Cocoa ☕️

LSPKit is design to easily integrate into the Cocoa Document Model and Text System. 

### Document - Simple Reading and Writing

| NSDocument | LSPClient |
|------|--------|
|- readFromURL: ofType: error: | - documentDidOpen: content: |
|- saveToURL: ofType: forSaveOperation: completionHandler: | - documentWillSave: |
|- writeToURL: ofType: forSaveOperation: originalContentsURL: error: | - documentDidSave: |
|- close | - documentDidClose: |

### Text Synchronization

LSPKit supports incremental document changes and uses coalescing on `-document:changeTextInRange:replacementString:`.

What does that mean? When the user types text and the `-textView:shouldChangeTextInRange:replacementString:` delegate gets called multiple times, `-document:changeTextInRange:replacementString:` doesn't post immediately a '*textDocument/didChange*' notification, but rather a notification is queued. Coalescing means that if a notification is posted which matches one already in the queue, the two are merged, so that only a single notification is posted to observers. When the user stops typing, the single '*textDocument/didChange*' notification in the queue (due to coalescing) is posted when the run loop enters its wait state.

### Termination Observer

`-addTerminationObserver:block:` makes it easy to restore the language server document state in case the language server process crashes.

### Bundles

Bundles are used to add language servers. Currently the two language servers [bash-language-server](https://github.com/mads-hartmann/bash-language-server) and [vscode-html-languageserver](https://github.com/Microsoft/vscode/tree/master/extensions/html-language-features/server) are included.

## Sample Script Editor

The sample shows how to integrate LSPKit and how to implement *NSTextView* features like highlight current line, highlighting of line for diagnotics, highlighting of words, and how to layout views left aligned to line content.

See highlight current line ([code](https://github.com/catlan/LSPKit/blob/cb4db0c45c0d0cdc8aad9e03bce33d93b80e06d5/Sample/Script%20Editor/Classes/Document.m#L288)) and highlighting of words ([code](https://github.com/catlan/LSPKit/blob/cb4db0c45c0d0cdc8aad9e03bce33d93b80e06d5/Sample/Script%20Editor/Classes/Document.m#L300)):
<img src="https://raw.githubusercontent.com/catlan/LSPKit/master/Sample/Screenshots/Screenshot%201@2x.png" width="592" />

Postion *NSPopover* on a word ([part1](https://github.com/catlan/LSPKit/blob/cb4db0c45c0d0cdc8aad9e03bce33d93b80e06d5/Sample/Script%20Editor/Classes/Document.m#L217), [part2](https://github.com/catlan/LSPKit/blob/cb4db0c45c0d0cdc8aad9e03bce33d93b80e06d5/Sample/Script%20Editor/Classes/Document.m#L663)): 
<img src="https://raw.githubusercontent.com/catlan/LSPKit/master/Sample/Screenshots/Screenshot%202@2x.png" width="741" />

Diagnostic view left aligned to line content ([code](https://github.com/catlan/LSPKit/blob/cb4db0c45c0d0cdc8aad9e03bce33d93b80e06d5/Sample/Script%20Editor/Classes/Document.m#L391)):
<img src="https://raw.githubusercontent.com/catlan/LSPKit/master/Sample/Screenshots/Screenshot%203@2x.png" width="592" />

## License

LSPKit is licensed under the [MIT license](https://github.com/catlan/LSPKit/blob/master/LICENSE.txt). 

## Feedback 

Get in touch via [twitter](https://twitter.com/catlan), an issue, or a pull request.
