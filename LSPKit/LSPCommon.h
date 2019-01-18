//
//  LSPCommon.h
//  LSPKit
//
//  Created by Christopher Atlan on 15.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSErrorDomain const LSPResponseError;

typedef NS_ENUM(NSUInteger, LSPErrorCode) {
    LSPResponseParseError = -32700,
    LSPResponseInvalidRequest = -32600,
    LSPResponseMethodNotFound = -32601,
    LSPResponseInvalidParams = -32602,
    LSPResponseInternalError = -32603,
    LSPResponseServerErrorStart = -32099,
    LSPResponseServerErrorEnd = -32000,
    LSPResponseServerNotInitialized = -32002,
    LSPResponseUnknownErrorCode = -32001,
    // Defined by the protocol.
    LSPResponseRequestCancelled = -32800,
    LSPResponseContentModified = -32801
};

typedef NS_ENUM(NSUInteger, LSPMessageType) {
    /**
     * An error message.
     */
    LSPMessageTypeError = 1,
    /**
     * A warning message.
     */
    LSPMessageTypeWarning = 2,
    /**
     * An information message.
     */
    LSPMessageTypeInfo = 3,
    /**
     * A log message.
     */
    LSPMessageTypeLog = 4
};

/**
 * A document highlight kind.
 */
typedef NS_ENUM(NSUInteger, LSPDocumentHighlightKind) {
    /**
     * A textual occurrence.
     */
    LSPDocumentHighlightKindText = 1,
    /**
     * Read-access of a symbol, like reading a variable.
     */
    LSPDocumentHighlightKindRead = 2,
    /**
     * Write-access of a symbol, like writing to a variable.
     */
    LSPDocumentHighlightKindWrite = 3,
};

/**
 * Position in a text document expressed as zero-based line and
 * zero-based character offset. A position is between two characters
 * like an ‘insert’ cursor in a editor.
 */
@interface LSPPosition : NSObject
/**
 * Line position in a document (zero-based).
 */
@property (readonly) NSUInteger line;
/**
 * Character offset on a line in a document (zero-based). Assuming that the line is
 * represented as a string, the `character` value represents the gap between the
 * `character` and `character + 1`.
 *
 * If the character value is greater than the line length it defaults back to the
 * line length.
 */
@property (readonly) NSUInteger character;

+ (instancetype)positionForCharacterAtIndex:(NSUInteger)location inText:(NSString *)string;
+ (instancetype)positionFromDictionary:(NSDictionary *)dict;
+ (instancetype)positionWithLine:(NSUInteger)line character:(NSUInteger)character;

- (NSUInteger)convertToPositionInText:(NSString *)string;

- (NSDictionary *)params;

@end

/**
 * A range in a text document expressed as (zero-based) start and end positions.
 * A range is comparable to a selection in an editor. Therefore the end position
 * is exclusive. If you want to specify a range that contains a line including
 * the line ending character(s) then use an end position denoting the start
 * of the next line.
 */
@interface LSPRange : NSObject
/**
 * The range's start position.
 */
@property (readonly) LSPPosition *start;
/**
 * The range's end position.
 */
@property (readonly) LSPPosition *end;

+ (instancetype)range:(NSRange)range inText:(NSString *)string;
+ (instancetype)rangeFromDictionary:(NSDictionary *)dict;
- (NSRange)convertToRangeInText:(NSString *)string;

@end

typedef NS_ENUM(NSUInteger, LSPDiagnosticSeverity) {
    LSPDiagnosticSeverityUnknown = 0,
    /**
     * Reports an error.
     */
    LSPDiagnosticSeverityError = 1,
    /**
     * Reports a warning.
     */
    LSPDiagnosticSeverityWarning = 2,
    /**
     * Reports an information.
     */
    LSPDiagnosticSeverityInformation = 3,
    /**
     * Reports a hint.
     */
    LSPDiagnosticSeverityHint = 4,
};

/**
 * Represents a diagnostic, such as a compiler error or warning. Diagnostic
 * objects are only valid in the scope of a resource.
 */
@interface LSPDiagnostic : NSObject
/**
 * The range at which the message applies.
 */
@property (readonly) LSPRange *range;
/**
 * The diagnostic's severity. Can be omitted. If omitted it is up to the
 * client to interpret diagnostics as error, warning, info or hint.
 */
@property (readonly) LSPDiagnosticSeverity severity;
/**
 * The diagnostic's code, which might appear in the user interface.
 */
@property (readonly) id code;
/**
 * A human-readable string describing the source of this
 * diagnostic, e.g. 'typescript' or 'super lint'.
 */
@property (readonly) NSString *source;
/**
 * The diagnostic's message.
 */
@property (readonly) NSString *message;
/**
 * An array of related diagnostic information, e.g. when symbol-names within
 * a scope collide all definitions can be marked via this property.
 */
@property (readonly) id relatedInformation;

+ (NSArray<LSPDiagnostic *> *)diagnosticsFromArray:(NSArray *)array;
+ (instancetype)diagnosticFromDictionary:(NSDictionary *)dict;

@end

/**
 * A document highlight is a range inside a text document which deserves
 * special attention. Usually a document highlight is visualized by changing
 * the background color of its range.
 *
 */
@interface LSPDocumentHighlight : NSObject
/**
 * The range this highlight applies to.
 */
@property (readonly) NSRange range;
@property (readonly) LSPDocumentHighlightKind kind;

- (instancetype)initWithRange:(NSRange)range kind:(LSPDocumentHighlightKind)kind;

@end

typedef NS_ENUM(NSUInteger, LSPCompletionItemKind) {
    LSPCompletionItemKindText = 1,
    LSPCompletionItemKindMethod = 2,
    LSPCompletionItemKindFunction = 3,
    LSPCompletionItemKindConstructor = 4,
    LSPCompletionItemKindField = 5,
    LSPCompletionItemKindVariable = 6,
    LSPCompletionItemKindClass = 7,
    LSPCompletionItemKindInterface = 8,
    LSPCompletionItemKindModule = 9,
    LSPCompletionItemKindProperty = 10,
    LSPCompletionItemKindUnit = 11,
    LSPCompletionItemKindValue = 12,
    LSPCompletionItemKindEnum = 13,
    LSPCompletionItemKindKeyword = 14,
    LSPCompletionItemKindSnippet = 15,
    LSPCompletionItemKindColor = 16,
    LSPCompletionItemKindFile = 17,
    LSPCompletionItemKindReference = 18,
    LSPCompletionItemKindFolder = 19,
    LSPCompletionItemKindEnumMember = 20,
    LSPCompletionItemKindConstant = 21,
    LSPCompletionItemKindStruct = 22,
    LSPCompletionItemKindEvent = 23,
    LSPCompletionItemKindOperator = 24,
    LSPCompletionItemKindTypeParameter = 25,
};

@interface LSPCompletionItem : NSObject
/**
 * The label of this completion item. By default
 * also the text that is inserted when selecting
 * this completion.
 */
@property (readonly) NSString *label;
/**
 * The kind of this completion item. Based of the kind
 * an icon is chosen by the editor.
 */
@property (readonly) LSPCompletionItemKind kind;
/**
 * A human-readable string with additional information
 * about this item, like type or symbol information.
 */
@property (readonly) NSString *detail;
/**
 * A human-readable string that represents a doc-comment.
 */
@property (readonly) NSString *documentation;
/**
 * Indicates if this item is deprecated.
 */
@property (readonly, getter=isDeprecated) BOOL deprecated;
/**
 * Select this item when showing.
 *
 * *Note* that only one completion item can be selected and that the
 * tool / client decides which item that is. The rule is that the *first*
 * item of those that match best is selected.
 */
@property (readonly, getter=isPreselect) BOOL preselect;
/**
 * A string that should be used when comparing this item
 * with other items. When `falsy` the label is used.
 */
@property (readonly) NSString *sortText;
/**
 * A string that should be used when filtering a set of
 * completion items. When `falsy` the label is used.
 */
@property (readonly) NSString *filterText;
/**
 * A string that should be inserted into a document when selecting
 * this completion. When `falsy` the label is used.
 *
 * The `insertText` is subject to interpretation by the client side.
 * Some tools might not take the string literally. For example
 * VS Code when code complete is requested in this example `con<cursor position>`
 * and a completion item with an `insertText` of `console` is provided it
 * will only insert `sole`. Therefore it is recommended to use `textEdit` instead
 * since it avoids additional client side interpretation.
 *
 * Deprecated: Use textEdit instead.
 */
@property (readonly) NSString *insertText;
/**
 * The format of the insert text. The format applies to both the `insertText` property
 * and the `newText` property of a provided `textEdit`.
 */
@property (readonly) NSString *insertTextFormat;
/**
 * An edit which is applied to a document when selecting this completion. When an edit is provided the value of
 * `insertText` is ignored.
 *
 * *Note:* The range of the edit must be a single line range and it must contain the position at which completion
 * has been requested.
 */
@property (readonly) id textEdit;
/**
 * An optional array of additional text edits that are applied when
 * selecting this completion. Edits must not overlap (including the same insert position)
 * with the main edit nor with themselves.
 *
 * Additional text edits should be used to change text unrelated to the current cursor position
 * (for example adding an import statement at the top of the file if the completion item will
 * insert an unqualified type).
 */
@property (readonly) NSArray<id> *additionalTextEdits;
/**
 * An optional set of characters that when pressed while this completion is active will accept it first and
 * then type that character. *Note* that all commit characters should have `length=1` and that superfluous
 * characters will be ignored.
 */
@property (readonly) NSArray<NSString *> *commitCharacters;
/**
 * An optional command that is executed *after* inserting this completion. *Note* that
 * additional modifications to the current document should be described with the
 * additionalTextEdits-property.
 */
@property (readonly) id command;
/**
 * An data entry field that is preserved on a completion item between
 * a completion and a completion resolve request.
 */
@property (readonly) id data;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end
