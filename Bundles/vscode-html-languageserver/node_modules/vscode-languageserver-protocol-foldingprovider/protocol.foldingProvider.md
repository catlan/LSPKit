#### Folding Range Request

The folding range request is sent from the client to the server to return all folding ranges found in a given text document.


_Server Capability_:

The server sets the following server capability if it is able to handle `textDocument/foldingRanges` requests:

```ts
/**
 * The server capabilities
 */
export interface FoldingRangeServerCapabilities {
	/**
	 * The server provides folding provider support.
	 */
	foldingRangeProvider?: FoldingRangeProviderOptions | (FoldingRangeProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions);
}

export interface FoldingRangeProviderOptions {
}
```


_Client Capability_:

The client sets the following client capability if it is able to support foldingRangeProviders.

```ts
export interface FoldingRangeClientCapabilities {
	/**
	 * The text document client capabilities
	 */
	textDocument?: {
		/**
		 * Capabilities specific to `textDocument/foldingRange` requests
		 */
		foldingRange?: {
			/**
			 * Whether implementation supports dynamic registration for folding range providers. If this is set to `true`
			 * the client supports the new `(FoldingRangeProviderOptions & TextDocumentRegistrationOptions & StaticRegistrationOptions)`
			 * return value for the corresponding server capability as well.
			 */
			dynamicRegistration?: boolean;
			/**
			 * The maximum number of folding ranges that the client prefers to receive per document. The value serves as a
			 * hint, servers are free to follow the limit.
			 */
			rangeLimit?: number;
			/**
			 * If set, the client signals that it only supports folding complete lines. If set, client will
			 * ignore specified `startCharacter` and `endCharacter` properties in a FoldingRange.
			 */
			lineFoldingOnly?: boolean;
		};
	};
}
```

_Request_:

* method: 'textDocument/foldingRanges'
* params: `FoldingRangeRequestParam` defined as follows

```ts
export interface FoldingRangeRequestParam {
	/**
	 * The text document.
	 */
	textDocument: TextDocumentIdentifier;
}

```

_Response_:
* result: `FoldingRange[] | null` defined as follows:
```ts

/**
 * Enum of known range kinds
 */
export enum FoldingRangeKind {
	/**
	 * Folding range for a comment
	 */
	Comment = 'comment',
	/**
	 * Folding range for a imports or includes
	 */
	Imports = 'imports',
	/**
	 * Folding range for a region (e.g. `#region`)
	 */
	Region = 'region'
}

/**
 * Represents a folding range.
 */
export interface FoldingRange {

	/**
	 * The zero-based line number from where the folded range starts.
	 */
	startLine: number;

	/**
	 * The zero-based character offset from where the folded range starts. If not defined, defaults to the length of the start line.
	 */
	startCharacter?: number;

	/**
	 * The zero-based line number where the folded range ends.
	 */
	endLine: number;

	/**
	 * The zero-based character offset before the folded range ends. If not defined, defaults to the length of the end line.
	 */
	endCharacter?: number;

	/**
	 * Describes the kind of the folding range such as `comment' or 'region'. The kind
	 * is used to categorize folding ranges and used by commands like 'Fold all comments'. See
	 * [FoldingRangeKind](#FoldingRangeKind) for an enumeration of standardized kinds.
	 */
	kind?: string;
}
```
* error: code and message set in case an exception happens during the 'textDocument/foldingRanges' request

