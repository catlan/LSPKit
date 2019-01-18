//
//  LSPCommon.m
//  LSPKit
//
//  Created by Christopher Atlan on 15.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "LSPCommon.h"

NSErrorDomain const LSPResponseError = @"LSPResponseError";

@implementation LSPPosition

+ (instancetype)positionFromDictionary:(NSDictionary *)dict {
    NSNumber *line = [dict objectForKey:@"line"];
    NSNumber *character = [dict objectForKey:@"character"];
    if ([line isKindOfClass:[NSNumber class]] && [character isKindOfClass:[NSNumber class]]) {
        return [[[self class] alloc] initWithLine:[line unsignedIntegerValue] character:[character unsignedIntegerValue]];
    }
    return nil;
}

+ (instancetype)positionForCharacterAtIndex:(NSUInteger)loc inText:(NSString *)string {
    LSPPosition *position = nil;
    NSUInteger lineNumber, index, stringLength = [string length];
    BOOL locationIsEndOfString = (loc == stringLength);
    if (locationIsEndOfString) {
        position = [LSPPosition positionWithLine:0 character:0];
    }
    for (index = 0, lineNumber = 0; index < stringLength; lineNumber++) {
        NSRange range = [string lineRangeForRange:NSMakeRange(index, 0)];
        BOOL locationInRange = NSLocationInRange(loc, range);
        BOOL isEndOfString = (stringLength == NSMaxRange(range));
        if (locationInRange || (isEndOfString && locationIsEndOfString)) {
            NSUInteger character = loc - index;
            position = [LSPPosition positionWithLine:lineNumber character:character];
            break;
        }
        index = NSMaxRange(range);
    }
    return position;
}

+ (instancetype)positionWithLine:(NSUInteger)line character:(NSUInteger)character {
    return [[[self class] alloc] initWithLine:line character:character];
}

- (instancetype)initWithLine:(NSUInteger)line character:(NSUInteger)character {
    self = [super init];
    if (self) {
        _line = line;
        _character = character;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{line = %lu, character = %lu}", (unsigned long)_line, (unsigned long)_character];
}

- (NSUInteger)convertToPositionInText:(NSString *)string {
    NSUInteger numberOfLines, index, stringLength = [string length];
    for (index = 0, numberOfLines = 0; index <= stringLength; numberOfLines++) {
        if (_line == numberOfLines) {
            return index + _character;
        }
        NSRange lineRange = [string lineRangeForRange:NSMakeRange(index, 0)];
        index = NSMaxRange(lineRange);
    }
    return NSNotFound;
}

- (NSDictionary *)params {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger:_line], @"line",
            [NSNumber numberWithUnsignedInteger:_character], @"character",
            nil];
}

@end

@implementation LSPRange

+ (instancetype)rangeFromDictionary:(NSDictionary *)dict {
    if ([dict isKindOfClass:[NSDictionary class]] == NO) return nil;
    LSPPosition *start = [LSPPosition positionFromDictionary:[dict objectForKey:@"start"]];
    LSPPosition *end = [LSPPosition positionFromDictionary:[dict objectForKey:@"end"]];
    return [[LSPRange alloc] initWithStart:start end:end];
}

+ (instancetype)range:(NSRange)range inText:(NSString *)string {
    LSPPosition *start = [LSPPosition positionForCharacterAtIndex:range.location inText:string];
    LSPPosition *end = [LSPPosition positionForCharacterAtIndex:NSMaxRange(range) inText:string];
    return [[LSPRange alloc] initWithStart:start end:end];
}

- (instancetype)initWithStart:(LSPPosition *)start end:(LSPPosition *)end {
    if (start == nil || end == nil) return nil;
    self = [super init];
    if (self) {
        _start = start;
        _end = end;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{start = %@ end = %@}", _start, _end];
}

- (NSRange)convertToRangeInText:(NSString *)string {
    NSUInteger startCharacterIndex = [_start convertToPositionInText:string];
    NSUInteger endCharacterIndex = [_end convertToPositionInText:string];
    return NSMakeRange(startCharacterIndex, endCharacterIndex - startCharacterIndex);
}

- (NSDictionary *)params {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [_start params], @"start",
            [_end params], @"end",
            nil];
}

@end


@interface LSPDiagnostic ()
@property (readwrite) LSPRange *range;
@property (readwrite) LSPDiagnosticSeverity severity;
@property (readwrite) id code;
@property (readwrite) NSString *source;
@property (readwrite) NSString *message;
@property (readwrite) id relatedInformation;
@end

@implementation LSPDiagnostic

+ (NSArray<LSPDiagnostic *> *)diagnosticsFromArray:(NSArray *)array {
    if ([array isKindOfClass:[NSArray class]] == NO) return nil;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSDictionary *dict in array) {
        LSPDiagnostic *diagnostic = [[self class] diagnosticFromDictionary:dict];
        if (diagnostic) {
            [result addObject:diagnostic];
        }
    }
    return [result copy];
}

+ (instancetype)diagnosticFromDictionary:(NSDictionary *)dict {
    if ([dict isKindOfClass:[NSDictionary class]] == NO) return nil;
    LSPDiagnostic *diagnostic = [[LSPDiagnostic alloc] init];
    diagnostic.range = [LSPRange rangeFromDictionary:[dict objectForKey:@"range"]];
    diagnostic.severity = [[dict objectForKey:@"severity"] integerValue];
    diagnostic.code = [dict objectForKey:@"code"];
    diagnostic.source = [dict objectForKey:@"source"];
    diagnostic.message = [dict objectForKey:@"message"];
    return diagnostic;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ message = %@ range = %@>", [self className], _message, _range];
}

@end

@implementation LSPCompletionItem

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        _label = [dict objectForKey:@"label"];
        _kind = [[dict objectForKey:@"kind"] integerValue];
        _detail = [dict objectForKey:@"detail"];
        _documentation = [dict objectForKey:@"documentation"];
        _deprecated = [[dict objectForKey:@"deprecated"] boolValue];
        _preselect = [[dict objectForKey:@"preselect"] boolValue];
        _sortText = [dict objectForKey:@"sortText"];
        _filterText = [dict objectForKey:@"filterText"];
        _insertText = [dict objectForKey:@"insertText"];
        _insertTextFormat = [dict objectForKey:@"insertTextFormat"];
        _textEdit = [dict objectForKey:@"textEdit"];
        _additionalTextEdits = [dict objectForKey:@"additionalTextEdits"];
        _commitCharacters = [dict objectForKey:@"commitCharacters"];
        _command = [dict objectForKey:@"command"];
        _data = [dict objectForKey:@"data"];
    }
    return self;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ label = %@>", [self className], _label];
}

@end


@implementation LSPDocumentHighlight

/*+ (NSRange)rangeFromDictionary:(NSDictionary *)dict {
 [dict objectForKey:@"start"];
 [dict objectForKey:@"end"];
 }
 
 + (instancetype)documentHighlightFromDictionary:(NSDictionary *)dict {
 [dict objectForKey:@"range"];
 return nil;
 }*/

- (instancetype)initWithRange:(NSRange)range kind:(LSPDocumentHighlightKind)kind {
    self = [super init];
    if (self) {
        _range = range;
        _kind = LSPDocumentHighlightKindText;
    }
    return self;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ range = %@>", [self className], NSStringFromRange(_range)];
}

@end

