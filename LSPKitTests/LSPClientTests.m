//
//  LSPClientTests.m
//  LSPKitTests
//
//  Created by Christopher Atlan on 12.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <LSPKit/LSPKit.h>



@interface DiagnosticsObserver : XCTestCase <LSPClientObserver>
@property XCTestExpectation *expectation;
@property NSURL *uri;
@end

@implementation DiagnosticsObserver

- (void)languageServer:(LSPClient *)client document:(NSURL *)url diagnostics:(NSArray<LSPDiagnostic *> *)diagnostics {
    if ([_uri isEqual:url] == NO) return;
    XCTAssertTrue([NSThread isMainThread], @"");
    XCTAssertEqual([diagnostics count], 1, @"");
    LSPDiagnostic *diagnostic = [diagnostics firstObject];
    XCTAssertEqual([[[diagnostic range] start] line], 12, @"");
    XCTAssertEqual([[[diagnostic range] start] character], 0, @"");
    XCTAssertEqual([[[diagnostic range] end] line], 12, @"");
    XCTAssertEqual([[[diagnostic range] end] character], 0, @"");
    [_expectation fulfill];
}

@end



@interface LSPClientTests : XCTestCase
@end

@implementation LSPClientTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testBashServerCapabilities {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"initialized"];
    LSPClient *client = [LSPClient sharedBashServer];
    [client initialWithCompletionHandler:^(NSError *error) {
        [expectation1 fulfill];
        XCTAssertTrue([NSThread isMainThread], @"");
        XCTAssertEqual(error, nil, @"");
        XCTAssertTrue([client textDocumentSync].openClose, @"");
        XCTAssertEqual([client textDocumentSync].change, LSPTextDocumentSyncKindFull, @"");
        XCTAssertTrue([client hasCompletionProvider], @"");
        XCTAssertTrue([client hasCompletionResolveProvider], @"");
        XCTAssertTrue([client hasDefinitionProvider], @"");
        XCTAssertTrue([client hasDocumentHighlightProvider], @"");
        XCTAssertTrue([client hasDocumentSymbolProvider], @"");
        XCTAssertTrue([client hasHoverProvider], @"");
        XCTAssertTrue([client hasReferencesProvider], @"");
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, nil] timeout:10.0];
}

- (void)testTextSynchronization {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"documentSymbol1"];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"documentSymbol2"];
    NSURL *scriptURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"Hello World" withExtension:@"sh"];
    NSString *text = [[NSString alloc] initWithContentsOfURL:scriptURL usedEncoding:NULL error:NULL];
    LSPClient *client = [LSPClient sharedBashServer];
    [client initialWithCompletionHandler:^(NSError *error) {
        XCTAssertTrue([NSThread isMainThread], @"");
        XCTAssertEqual(error, nil, @"");
        
        [client documentDidOpen:scriptURL content:text];

        [client documentSymbol:scriptURL completionHandler:^(NSArray *symbols, NSError *error) {
            XCTAssertTrue([NSThread isMainThread], @"");
            XCTAssertEqual([symbols count], 1, @"");
            NSDictionary *symbol1 = [symbols objectAtIndex:0];
            XCTAssertEqualObjects([symbol1 objectForKey:@"name"], @"VAR1", @"");
            [expectation1 fulfill];
        }];
        
        NSString *replacementString = @"VAR2=\" looking\"\necho $VAR2\n";
        NSRange range = NSMakeRange(179, 0);
        NSMutableString *newText = [text mutableCopy];
        [newText insertString:replacementString atIndex:range.location];
        [client document:scriptURL changeTextInRange:range replacementString:replacementString];
        
        // Normally not required, but in the unit test the run loop
        // never enters the idle state (NSPostWhenIdle).
        [client documentDidChange:scriptURL];
        
        [client documentSymbol:scriptURL completionHandler:^(NSArray *symbols, NSError *error) {
            XCTAssertTrue([NSThread isMainThread], @"");
            XCTAssertEqual([symbols count], 2, @"");
            NSDictionary *symbol2 = [symbols objectAtIndex:1];
            XCTAssertEqualObjects([symbol2 objectForKey:@"name"], @"VAR2", @"");
            [expectation2 fulfill];
        }];
        
        [client documentDidClose:scriptURL];
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, expectation2, nil] timeout:10.0];
}

- (void)testDiagnostics {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"initialized"];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"diagnostics"];
    NSURL *scriptURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"missing-node" withExtension:@"sh"];
    NSString *text = [[NSString alloc] initWithContentsOfURL:scriptURL usedEncoding:NULL error:NULL];
    
    DiagnosticsObserver *observer = [[DiagnosticsObserver alloc] init];
    observer.expectation = expectation2;
    observer.uri = scriptURL;
    
    LSPClient *client = [LSPClient sharedBashServer];
    [client addObserver:observer];
    [client initialWithCompletionHandler:^(NSError *error) {
        XCTAssertTrue([NSThread isMainThread], @"");
        [expectation1 fulfill];
        
        [client documentDidOpen:scriptURL content:text];
        [client documentDidClose:scriptURL];
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, expectation2, nil] timeout:10.0];
}

- (void)testHTMLServerCapabilities {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"initialized"];
    LSPClient *client = [LSPClient sharedHTMLServer];
    [client initialWithCompletionHandler:^(NSError *error) {
        [expectation1 fulfill];
        
        XCTAssertEqual(error, nil, @"");
        XCTAssertTrue([client hasColorProvider], @"");
        XCTAssertTrue([client hasDefinitionProvider], @"");
        XCTAssertTrue([client hasDocumentHighlightProvider], @"");
        XCTAssertTrue([client hasDocumentLinkProvider], @"");
        XCTAssertFalse([client documentLinkProviderResolveProvider], @"");
        XCTAssertFalse([client hasDocumentRangeFormattingProvider], @"");
        XCTAssertTrue([client hasDocumentSymbolProvider], @"");
        XCTAssertTrue([client hasFoldingRangeProvider], @"");
        XCTAssertTrue([client hasHoverProvider], @"");
        XCTAssertTrue([client hasReferencesProvider], @"");
        XCTAssertTrue([client hasSignatureHelpProvider], @"");
        
        XCTAssertEqual([client textDocumentSync].change, LSPTextDocumentSyncKindFull, @"");
        XCTAssertTrue([client textDocumentSync].openClose, @"");
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, nil] timeout:10.0];
}

- (void)testUnexpectedTermination {
    XCTestExpectation *expectation1 = [[XCTestExpectation alloc] initWithDescription:@"initialized"];
    XCTestExpectation *expectation2 = [[XCTestExpectation alloc] initWithDescription:@"termination"];
    LSPClient *client = [LSPClient sharedBashServer];
    [client addTerminationObserver:self block:^(LSPClient *client) {
        XCTAssertTrue([NSThread isMainThread], @"");
        [expectation2 fulfill];
    }];
    [client initialWithCompletionHandler:^(NSError *error) {
        [expectation1 fulfill];
        NSTask *task = [client valueForKey:@"task"];
        [task terminate];
    }];
    [self waitForExpectations:[NSArray arrayWithObjects:expectation1, expectation2, nil] timeout:30.0];
}

- (void)testLSPPositon {
    LSPPosition *position1 = [LSPPosition positionForCharacterAtIndex:0 inText:@""];
    XCTAssertEqual(position1.line, 0, @"");
    XCTAssertEqual(position1.character, 0, @"");
    LSPPosition *position2 = [LSPPosition positionForCharacterAtIndex:2 inText:@"\n\n123"];
    XCTAssertEqual(position2.line, 2, @"");
    XCTAssertEqual(position2.character, 0, @"");
    LSPPosition *position3 = [LSPPosition positionForCharacterAtIndex:3 inText:@"\n\n123"];
    XCTAssertEqual(position3.line, 2, @"");
    XCTAssertEqual(position3.character, 1, @"");
    LSPPosition *position4 = [LSPPosition positionForCharacterAtIndex:5 inText:@"\n\n123"];
    XCTAssertEqual(position4.line, 2, @"");
    XCTAssertEqual(position4.character, 3, @"");
}

@end
