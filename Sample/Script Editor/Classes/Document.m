//
//  Document.m
//  Script Editor
//
//  Created by Christopher Atlan on 13.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "Document.h"

#import "NoodleLineNumberView.h"
#import <Carbon/Carbon.h>
#import <LSPKit/LSPKit.h>


#pragma mark NSTextContainer

@interface NSTextContainer (FancyEditor)
@end

@implementation NSTextContainer (FancyEditor)

// Based on -[NSTextContainer setExclusionPaths:]
- (void)lsp_setNeedDisplay {
    NSLayoutManager *layoutManager = [self layoutManager];
    if ([[layoutManager textStorage] length]) {
        NSRange range = NSMakeRange(0, 0);
        NSArray *textContainers = [layoutManager textContainers];
        NSTextContainer *textContainer = [layoutManager textContainerForGlyphAtIndex:0 effectiveRange:&range withoutAdditionalLayout:YES];
        if (textContainer) {
            if ([textContainers count]) {
                if (textContainer != self) {
                    NSUInteger glyphIndex = NSMaxRange(range);
                    do {
                        textContainer = [layoutManager textContainerForGlyphAtIndex:glyphIndex effectiveRange:&range withoutAdditionalLayout:YES];
                        glyphIndex = NSMaxRange(range);
                    } while (textContainer && textContainer != self);
                }
            }
            NSTextView *textView = [textContainer textView];
            if (textView) {
                [textView setNeedsDisplayInRect:[textView bounds] avoidAdditionalLayout:NO];
            }
        }
        [layoutManager textContainerChangedGeometry:self];
    }
}

@end

#pragma mark DiagnosticViewController

@interface DiagnosticViewController : NSViewController <NSPopoverDelegate>
/** When binding the value/attributed string to NSTextView the editable property changes. An additional binding of editable fixes this   */
@property IBOutlet NSTextView *textView;
@property NSRange characterRange;
@end

@implementation DiagnosticViewController

- (void)viewDidLoad {
    NSView *view = [self view];
    [_textView setBackgroundColor:[NSColor colorWithRed:255.0/255.0 green:195.0/255.0  blue:180.0/255.0  alpha:1.0]];
    [_textView setFrame:[view bounds]];
    [_textView setDefaultParagraphStyle:[self paragraphStyle]];
    [_textView setString:[self representedObject]];
    [view addSubview:_textView];
    
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    [_textView setDefaultParagraphStyle:[self paragraphStyle]];
    [_textView setString:representedObject];
}

- (NSParagraphStyle *)paragraphStyle {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    paragraphStyle.allowsDefaultTighteningForTruncation = NO;
    return [paragraphStyle copy];
}

- (void)cancelOperation:(id)sender {
    [self dismissController:sender];
}

@end

#pragma mark TooltipViewController

@interface TooltipViewController : NSViewController
/** When binding the value/attributed string to NSTextView the editable property changes. An additional binding of editable fixes this   */
@property IBOutlet NSTextView *textView;
@end

@implementation TooltipViewController

- (void)cancelOperation:(id)sender {
    [self dismissController:sender];
}

@end

#pragma mark ScriptTextView

@class ScriptTextView;

@protocol ScriptTextViewDelegate <NSTextViewDelegate>

- (void)textView:(ScriptTextView *)textView complete:(id)sender;
- (void)textView:(ScriptTextView *)textView tooltip:(id)sender forCharacterAtIndex:(NSUInteger)characterIndex point:(NSPoint)point;

- (NSView *)textView:(ScriptTextView *)textView diagnosticViewForCharacterRange:(NSRange)range;

@end


@interface ScriptTextViewHighlight : NSObject
@property (readonly) NSRange range;
@property (readonly) NSColor *color;
@end

@implementation ScriptTextViewHighlight

+ (instancetype)highlight:(NSColor *)color range:(NSRange)range {
    return [[[self class] alloc] initWithColor:color range:range];
}

- (instancetype)initWithColor:(NSColor *)color range:(NSRange)range {
    self = [super init];
    if (self) {
        _color = color;
        _range = range;
    }
    return self;
}

@end

@interface ScriptTextView : NSTextView <NSLayoutManagerDelegate>
@property (weak) id<ScriptTextViewDelegate> delegate;
@property (nonatomic) NSColor *currentLineHighlightColor;
@property (nonatomic) NSArray<ScriptTextViewHighlight *> *lineHighlights;
@property (nonatomic) NSArray<ScriptTextViewHighlight *> *wordHighlights;
@end

@implementation ScriptTextView

@dynamic delegate;

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect textContainer:(NSTextContainer *)container {
    self = [super initWithFrame:frameRect textContainer:container];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [[self layoutManager] setDelegate:self];
    [self setDrawsBackground:YES];
}

- (BOOL)drawsBackground {
    return YES;
}

- (void)complete:(id)sender {
    id<ScriptTextViewDelegate> delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(textView:complete:)]) {
        [delegate textView:self complete:sender];
    } else {
        [super complete:sender];
    }
}

- (void)showCompleteList:(id)sender {
    [super complete:sender];
}

- (void)keyDown:(NSEvent *)event {
    if ([event keyCode] == kVK_Escape) {
        [NSApp sendAction:@selector(complete:) to:nil from:self];
    } else if ([event keyCode] == kVK_Option) {
        [[NSCursor crosshairCursor] push];
        [super keyDown:event];
    } else {
        [super keyDown:event];
    }
}

- (void)mouseDown:(NSEvent *)event {
    if ([event modifierFlags] & NSEventModifierFlagOption) {
        [self tooltip:event];
    } else {
        [super mouseDown:event];
    }
}

- (void)tooltip:(NSEvent *)event {
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterIndexForInsertionAtPoint:point];
    id<ScriptTextViewDelegate> delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(textView:tooltip:forCharacterAtIndex:point:)]) {
        [delegate textView:self tooltip:nil forCharacterAtIndex:characterIndex point:point];
    }
}

- (NSRect)rectForCharacterRange:(NSRange)charRange {
    NSLayoutManager *layoutManager = [self layoutManager];
    NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:charRange actualCharacterRange:NULL];
    NSRect rect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
    NSPoint containerOrigin = [self textContainerOrigin];
    rect.origin.x += containerOrigin.x;
    rect.origin.y += containerOrigin.y;
    return rect;
}

- (BOOL)hasExtraLine {
    NSString *str = [self string];
    NSUInteger length = [str length];
    if (length == 0) return YES;
    NSRange range = [str rangeOfComposedCharacterSequenceAtIndex:length - 1]; // Unicode Line Separator (LSEP)
    NSString *end = [str substringWithRange:range];
    NSString *result = [end stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    return ([result length] == 0);
}

- (void)drawViewBackgroundInRect:(NSRect)rect {
    [super drawViewBackgroundInRect:rect];
    
    NSLayoutManager *layoutManager = [self layoutManager];
    NSTextStorage *textStorage = [self textStorage];
    NSPoint containerOrigin = [self textContainerOrigin];
    NSRange glyphRange, charRange, paragraphCharRange, paragraphGlyphRange;
    NSRange selectedRange = [self selectedRange];
    NSUInteger stringLength = [[self string] length];
    BOOL hasExtraLine = [self hasExtraLine];
    BOOL hasNoExtraLine = !hasExtraLine;
    
    if ([_lineHighlights count] == 0 && [_wordHighlights count] == 0 && _currentLineHighlightColor == nil)
        return;
    
    // Couldn't get NSTextView to call -drawViewBackgroundInRect:
    // with big enough rect or the rect of the lines to highlight.
    if ([_lineHighlights count]) {
        rect = [[self enclosingScrollView] documentVisibleRect];
    }
    
    // Convert from view to container coordinates, then to the corresponding glyph and character ranges.
    rect.origin.x -= containerOrigin.x;
    rect.origin.y -= containerOrigin.y;
    glyphRange = [layoutManager glyphRangeForBoundingRect:rect inTextContainer:[self textContainer]];
    charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
    
    // Iterate through the character range, paragraph by paragraph.
    for (paragraphCharRange = NSMakeRange(charRange.location, 0);
         NSMaxRange(paragraphCharRange) < NSMaxRange(charRange);
         paragraphCharRange = NSMakeRange(NSMaxRange(paragraphCharRange), 0)) {
        // For each paragraph, find the corresponding character and glyph ranges.
        paragraphCharRange = [[textStorage string] paragraphRangeForRange:paragraphCharRange];
        paragraphGlyphRange = [layoutManager glyphRangeForCharacterRange:paragraphCharRange actualCharacterRange:NULL];
        
        for (ScriptTextViewHighlight *highlight in _lineHighlights) {
            if (NSLocationInRange(highlight.range.location, paragraphCharRange)) {
                NSRect paragraphRect = [self paragraphRectInGlyphRange:paragraphGlyphRange];
                [self drawLineBackgroundInRect:paragraphRect color:[highlight color]];
            }
        }
        
        if (_currentLineHighlightColor && selectedRange.length == 0) {
            BOOL isEndOfFile = (selectedRange.location == stringLength);
            BOOL isEndOfParagraph =  (selectedRange.location == NSMaxRange(paragraphCharRange));
            if (hasNoExtraLine && isEndOfFile && isEndOfParagraph) {
                NSRect paragraphRect = [self paragraphRectInGlyphRange:paragraphGlyphRange];
                [self drawLineBackgroundInRect:paragraphRect color:_currentLineHighlightColor];
            } else if (NSLocationInRange(selectedRange.location, paragraphCharRange)) {
                NSRect paragraphRect = [self paragraphRectInGlyphRange:paragraphGlyphRange];
                [self drawLineBackgroundInRect:paragraphRect color:_currentLineHighlightColor];
            }
        }
        
        for (ScriptTextViewHighlight *highlight in _wordHighlights) {
            NSRange highlightRange = [highlight range];
            NSColor *highlightColor = [highlight color];
            NSRange intersectionRange = NSIntersectionRange(paragraphCharRange, highlightRange);
            if (intersectionRange.length != 0) {
                NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:intersectionRange actualCharacterRange:NULL];
                NSRect wordRect = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
                [self drawRoundedRectAroundTextInRect:wordRect color:highlightColor];
            }
        }
    }
    
    if (hasExtraLine) {
        // lineHighlights in extraLineFragment
        for (ScriptTextViewHighlight *highlight in _lineHighlights) {
            if (highlight.range.location == stringLength) {
                [self drawLineBackgroundInRect:[layoutManager extraLineFragmentRect] color:[highlight color]];
            }
        }
        // currentLineHighlightColor in extraLineFragment
        if (_currentLineHighlightColor) {
            if (stringLength == selectedRange.location && selectedRange.length == 0) {
                [self drawLineBackgroundInRect:[layoutManager extraLineFragmentRect] color:_currentLineHighlightColor];
            }
        }
        // diagnosticView in extraLineFragment
        NSRange extraLineFragmentRange = NSMakeRange(stringLength, 0);
        NSView *view = [[self delegate] textView:self diagnosticViewForCharacterRange:extraLineFragmentRange];
        if (view) {
            NSRect extraLineFragmentRect = [layoutManager extraLineFragmentRect];
            NSRect extraLineFragmentUsedRect = [layoutManager extraLineFragmentUsedRect];
            [self layoutDiagnosticView:view inLineFragmentRect:&extraLineFragmentRect lineFragmentUsedRect:&extraLineFragmentUsedRect];
        }
    }
}

- (NSRect)paragraphRectInGlyphRange:(NSRange)paragraphGlyphRange {
    NSLayoutManager *layoutManager = [self layoutManager];
    NSPoint containerOrigin = [self textContainerOrigin];
    NSRange lineGlyphRange = NSMakeRange(0, 0);
    NSRect paragraphRect = NSZeroRect;
    // Iterate through the paragraph glyph range, line by line.
    for (lineGlyphRange = NSMakeRange(paragraphGlyphRange.location, 0);
         NSMaxRange(lineGlyphRange) < NSMaxRange(paragraphGlyphRange);
         lineGlyphRange = NSMakeRange(NSMaxRange(lineGlyphRange), 0))
    {
        // For each line, find the used rect and glyph range, and add the used rect to the paragraph rect.
        NSRect lineUsedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:lineGlyphRange.location effectiveRange:&lineGlyphRange];
        paragraphRect = NSUnionRect(paragraphRect, lineUsedRect);
    }
    
    paragraphRect.size.width = [self bounds].size.width;
    // Convert back from container to view coordinates, then draw the bubble.
    paragraphRect.origin.x += containerOrigin.x;
    paragraphRect.origin.y += containerOrigin.y;
    return paragraphRect;
}

- (void)drawLineBackgroundInRect:(NSRect)paragraphRect color:(NSColor *)highlightColor {
    [highlightColor set];
    [NSBezierPath fillRect:paragraphRect];
}

- (void)drawRoundedRectAroundTextInRect:(NSRect)paragraphRect color:(NSColor *)highlightColor {
    [highlightColor set];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:paragraphRect xRadius:2.0 yRadius:2.0];
    [path fill];
}


- (void)setSelectedRanges:(NSArray<NSValue *> *)ranges affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
    [super setSelectedRanges:ranges affinity:affinity stillSelecting:stillSelectingFlag];
    if (_currentLineHighlightColor) {
        [self setNeedsDisplayInRect:[self bounds] avoidAdditionalLayout:YES];
    }
}

- (void)setLineHighlights:(NSArray<ScriptTextViewHighlight *> *)highlightRanges {
    if (_lineHighlights != highlightRanges) {
        _lineHighlights = [highlightRanges copy];
        [self setNeedsDisplay:YES];
    }
}

- (void)setWordHighlights:(NSArray<ScriptTextViewHighlight *> *)wordHighlightRanges {
    if (_wordHighlights != wordHighlightRanges) {
        _wordHighlights = [wordHighlightRanges copy];
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)layoutManager:(NSLayoutManager *)layoutManager shouldSetLineFragmentRect:(inout NSRect *)lineFragmentRect lineFragmentUsedRect:(inout NSRect *)lineFragmentUsedRect baselineOffset:(inout CGFloat *)baselineOffset inTextContainer:(NSTextContainer *)textContainer forGlyphRange:(NSRange)glyphRange {
    
    NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
    NSView *view = [[self delegate] textView:self diagnosticViewForCharacterRange:charRange];
    if (view) {
        [self layoutDiagnosticView:view inLineFragmentRect:lineFragmentRect lineFragmentUsedRect:lineFragmentUsedRect];
    }
    return (view != nil);
}

- (void)layoutDiagnosticView:(NSView *)view inLineFragmentRect:(inout NSRect *)lineFragmentRect lineFragmentUsedRect:(inout NSRect *)lineFragmentUsedRect {
    NSRect rect = *lineFragmentRect;
    NSRect usedRect = *lineFragmentUsedRect;
    NSRect viewRect = {
        .origin = {.x = NSMaxX(usedRect), .y = usedRect.origin.y},
        .size = {
            .width = NSWidth(rect) - NSWidth(usedRect),
            .height = NSHeight(usedRect)
        }
    };
    view.frame = viewRect;
    if ([view superview] != self) {
        [self addSubview:view];
    }
}

@end

#pragma mark DocumentViewController

@interface DocumentWindowController : NSWindowController
@end

@implementation DocumentWindowController

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        self.shouldCascadeWindows = YES; // See rdar://47350352
    }
    return self;
}

@end

#pragma mark DocumentViewController

@interface DocumentViewController : NSViewController
@property IBOutlet ScriptTextView *textView;
@property NSString *representedObject;
@property (nonatomic, weak) IBOutlet id<ScriptTextViewDelegate> textViewDelegate;
@end

@implementation DocumentViewController

@dynamic representedObject;

- (void)viewDidLoad {
    _textView.currentLineHighlightColor = [NSColor colorWithRed:0.909804 green:0.950667 blue:0.999799 alpha:1.0];
    
    NoodleLineNumberView *lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:[_textView enclosingScrollView]];
    [[_textView enclosingScrollView] setVerticalRulerView:lineNumberView];
    [[_textView enclosingScrollView] setHasHorizontalRuler:NO];
    [[_textView enclosingScrollView] setHasVerticalRuler:YES];
    [[_textView enclosingScrollView] setRulersVisible:YES];
    
}

- (void)setRepresentedObject:(NSString *)representedObject {
    [super setRepresentedObject:representedObject];
}

- (void)setTextViewDelegate:(id<ScriptTextViewDelegate>)textViewDelegate {
    if (_textViewDelegate != textViewDelegate) {
        _textViewDelegate = textViewDelegate;
        _textView.delegate = textViewDelegate;
    }
}

@end

#pragma mark Document

@interface Document () <ScriptTextViewDelegate, LSPClientObserver> {
    NSRange _wordSelectionRange;
}
@property (nonatomic, copy) NSString *content;
@property LSPClient *langClient;
@property NSWindowController *mainWindowController;
@property DocumentViewController *documentViewController;
@property TooltipViewController *tooltipViewController;
@property NSMutableArray<DiagnosticViewController *> *diagnosticViewControllers;
@property NSArray<LSPCompletionItem *> *completionList;
@end

@implementation Document

@synthesize content = _content;

+ (BOOL)autosavesInPlace {
    return NO;
}

#pragma mark Initialize / Close

- (instancetype)init {
    self = [super init];
    if (self) {
        _diagnosticViewControllers = [NSMutableArray array];
        _langClient = [LSPClient sharedBashServer];
        [_langClient addObserver:self];
        __weak __typeof(self) weakSelf = self;
        [_langClient addTerminationObserver:self block:^(LSPClient *client) {
            __strong __typeof(self) strongSelf = weakSelf;
            [strongSelf languageServerTerminated:client];
        }];
    }
    return self;
}

// Handle Untiled documents.
//
// -[NSDocumentController newDocument:]:
//   -[NSDocumentController openUntitledDocumentAndDisplay:error:]:
//     -[NSDocument initWithType:error:]
- (instancetype)initWithType:(NSString *)typeName error:(NSError * _Nullable __autoreleasing *)outError {
    self = [super initWithType:typeName error:outError];
    if (self) {
        __weak __typeof(self) weakSelf = self;
        [_langClient initialWithCompletionHandler:^(NSError *error) {
            __strong __typeof(self) strongSelf = weakSelf;
            [[strongSelf langClient] documentDidOpen:[strongSelf URI] content:[self content]];
        }];
    }
    return self;
}

- (void)makeWindowControllers {
    _mainWindowController = [[NSStoryboard storyboardWithName:@"Document" bundle:nil] instantiateInitialController];
    _documentViewController = (id)[_mainWindowController contentViewController];
    _documentViewController.representedObject = _content;
    _documentViewController.textViewDelegate = self;
    [self addWindowController:_mainWindowController];
}

- (void)close {
    [super close];
    self.mainWindowController = nil;
    self.documentViewController = nil;
    self.tooltipViewController = nil;
    self.diagnosticViewControllers = nil;
    [_langClient documentDidClose:[self URI]];
    [_langClient removeObserver:self];
    [_langClient removeTerminationObserver:self];
}

#pragma mark Language Server termination

- (void)languageServerTerminated:(LSPClient *)client {
    __weak __typeof(self) weakSelf = self;
    [client initialWithCompletionHandler:^(NSError *error) {
        __strong __typeof(self) strongSelf = weakSelf;
        [[strongSelf langClient] documentDidOpen:[strongSelf URI] content:[strongSelf content]];
    }];
}

#pragma mark Read / Write

- (BOOL)readFromURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError {
    NSError *error = nil;
    NSString *text = [[NSString alloc] initWithContentsOfURL:url usedEncoding:NULL error:&error];
    if (text == nil) {
        if (*outError) {
            *outError = error;
        }
        return NO;
    }
    self.content = text;
    __weak __typeof(self) weakSelf = self;
    [_langClient initialWithCompletionHandler:^(NSError *error) {
        __strong __typeof(self) strongSelf = weakSelf;
        [[strongSelf langClient] documentDidOpen:[strongSelf URI] content:[strongSelf content]];
    }];
    return YES;
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
    [_langClient documentWillSave:[self URI]];
    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}

- (BOOL)writeToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError * _Nullable __autoreleasing *)outError
{
    BOOL success = [[self content] writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:outError];
    if (success) {
        [_langClient documentDidSave:[self URI]];
    }
    return success;
}

#pragma mark Properties

/* In case you think about using bindings, they get too late updated */
- (NSString *)content {
    NSTextView *textView = [_documentViewController textView];
    if (textView) {
        return [textView string];
    } else {
        return _content;
    }
}

- (NSURL *)URI {
    if ([self fileURL]) {
        return [self fileURL];
    } else {
        NSURLComponents *urlComponents = [[NSURLComponents alloc] init];
        [urlComponents setScheme:@"untitled"];
        [urlComponents setPath:[self displayName]];
        return [urlComponents URL];
    }
}

#pragma mark TextView Delegate

- (void)textViewDidChangeSelection:(NSNotification *)notification {
    ScriptTextView *textView = [notification object];
    NSRange wordSelectionRange = [textView selectionRangeForProposedRange:[textView selectedRange] granularity:NSSelectByWord];
    if (NSEqualRanges(_wordSelectionRange, wordSelectionRange) == NO) {
        [_langClient documentHighlight:[self URI] inText:[self content] forCharacterAtIndex:wordSelectionRange.location completionHandler:^(NSArray<LSPDocumentHighlight *> *highlights, NSError *error) {
            NSColor *color = [NSColor colorWithRed:221.0/255.0 green:228.0/255.0 blue:244.0/255.0 alpha:1.0];
            NSMutableArray *wordHighlights = [NSMutableArray arrayWithCapacity:[highlights count]];
            for (LSPDocumentHighlight *highlight in highlights) {
                ScriptTextViewHighlight *item = [ScriptTextViewHighlight highlight:color range:[highlight range]];
                [wordHighlights addObject:item];
            }
            [textView setWordHighlights:wordHighlights];
        }];
        _wordSelectionRange = wordSelectionRange;
    }
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString {
    [_langClient document:[self URI] changeTextInRange:affectedCharRange replacementString:replacementString];
    return YES;
}

- (void)textView:(ScriptTextView *)textView complete:(id)sender {
    [_langClient documentCompletion:[self URI] inText:[self content] forCharacterAtIndex:[textView selectedRange].location completionHandler:^(NSArray<LSPCompletionItem *> *completionList, BOOL isIncomplete, NSError *error) {
        self.completionList = completionList;
        [textView showCompleteList:sender];
    }];
}

- (NSArray<NSString *> *)textView:(NSTextView *)textView completions:(NSArray<NSString *> *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
    if (_completionList == nil) return [NSArray array];
    NSArray *completionList = [_completionList valueForKeyPath:@"label"];
    return completionList;
}

- (void)textView:(ScriptTextView *)textView tooltip:(id)sender forCharacterAtIndex:(NSUInteger)characterIndex point:(NSPoint)point {
    [_langClient documentHoverWithContentsOfURL:[self URI] inText:[self content] forCharacterAtIndex:characterIndex completionHandler:^(NSDictionary *dict, NSError *error) {
        if (dict) {
            NSDictionary *contents = [dict objectForKey:@"contents"];
            NSString *tooltip = [contents objectForKey:@"value"];
            [self textView:textView displayToolTip:tooltip forCharacterAtIndex:characterIndex point:point];
        }
    }];
}

- (void)textView:(ScriptTextView *)textView displayToolTip:(NSString *)tooltip forCharacterAtIndex:(NSUInteger)characterIndex point:(NSPoint)point {
    _tooltipViewController = [[NSStoryboard storyboardWithName:@"Tooltip" bundle:nil] instantiateInitialController];
    _tooltipViewController.representedObject = tooltip;
    [_documentViewController presentViewController:_tooltipViewController asPopoverRelativeToRect:[textView rectForCharacterRange:NSMakeRange(characterIndex, 1)] ofView:textView preferredEdge:NSRectEdgeMaxY behavior:NSPopoverBehaviorSemitransient];
}

- (void)clearDiagnostics {
    for (DiagnosticViewController *diagnosticViewController in _diagnosticViewControllers) {
        if ([diagnosticViewController isViewLoaded]) {
            [[diagnosticViewController view] removeFromSuperview];
        }
    }
    [_diagnosticViewControllers removeAllObjects];
}

- (void)languageServer:(LSPClient *)client document:(NSURL *)url diagnostics:(NSArray<LSPDiagnostic *> *)diagnostics {
    if ([url isEqual:[self URI]] == NO) {
        return;
    }
    ScriptTextView *textView = [_documentViewController textView];
    NSString *text = [[_documentViewController textView] string];
    NSColor *errorColor = [NSColor colorWithRed:254.0/255.0 green:239.0/255.0 blue:234.0/255.0 alpha:1.0];
    
    [self clearDiagnostics];
    
    NSMutableArray *highlightLines = [NSMutableArray arrayWithCapacity:[diagnostics count]];
    for (LSPDiagnostic *diagnostic in diagnostics) {
        NSRange range = [[diagnostic range] convertToRangeInText:text];
        
        ScriptTextViewHighlight *item = [ScriptTextViewHighlight highlight:errorColor range:range];
        [highlightLines addObject:item];
        
        DiagnosticViewController *diagnosticViewController = [[NSStoryboard storyboardWithName:@"Diagnostic" bundle:nil] instantiateInitialController];
        diagnosticViewController.representedObject = [diagnostic message];
        diagnosticViewController.characterRange = range;
        [_diagnosticViewControllers addObject:diagnosticViewController];
    }
    [textView setLineHighlights:highlightLines];
    [[textView textContainer] lsp_setNeedDisplay];
}

- (NSView *)textView:(ScriptTextView *)textView diagnosticViewForCharacterRange:(NSRange)charRange {
    for (DiagnosticViewController *diagnosticViewController in _diagnosticViewControllers) {
        NSRange diagnosticRange = diagnosticViewController.characterRange;
        NSRange range = NSIntersectionRange(diagnosticRange, charRange);
        if (NSEqualRanges(diagnosticRange, charRange) || NSLocationInRange(diagnosticRange.location, charRange)) {
            return [diagnosticViewController view];
        } else if (range.length > 0) {
            return [diagnosticViewController view];
        }
    }
    return nil;
}

@end
