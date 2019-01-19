//
//  LSPClient.m
//  LSPKit
//
//  Created by Christopher Atlan on 12.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "LSPClient.h"

#import "LSPCommon.h"



NSNotificationName const LSPDocumentDidChangeNotification = @"LSPDocumentDidChange";
NSString * const LSPDocumentUserInfoKey = @"Document";

typedef void (^ReplyBlock)(NSDictionary *, NSError *);

@interface LSPPipeline : NSObject {
    NSUInteger _messageID;
    NSMutableData *_buffer;
    CFHTTPMessageRef _message;
    NSMutableDictionary <NSNumber *, ReplyBlock> *_replyBlocks;
}
@property NSPipe *stdinPipe;
@property NSPipe *stdoutPipe;
@property NSPipe *stderrPipe;
@property (copy) void (^readHandler)(NSData *);
@property (copy) void (^dataHandler)(NSData *content, NSString *charset);
@property (copy) void (^notificationMessageHandler)(NSDictionary *message);
@property NSMutableString *log;
@end

@interface LSPPipeline (MessageTransport)
- (void)didReceiveData:(NSData *)data;
- (void)sendMessage:(NSData *)data;
@end

@interface LSPPipeline (ProtocolTransport)
- (void)handlePipelineMessage:(NSData *)data;
@end


@implementation LSPPipeline

- (instancetype)init
{
    self = [super init];
    if (self) {
        _buffer = [NSMutableData data];
        _replyBlocks = [NSMutableDictionary dictionary];
        _stdinPipe = [NSPipe pipe];
        _stdoutPipe = [NSPipe pipe];
        _stderrPipe = [NSPipe pipe];
        [[_stdoutPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fileHandle) {
            NSData *data = [fileHandle availableData];
            if ([data length] == 0) return;
            if (self.readHandler == nil) return;
            self.readHandler(data);
        }];
        [[_stderrPipe fileHandleForReading] setReadabilityHandler:^(NSFileHandle *fileHandle) {
            NSData *data = [fileHandle availableData];
            if ([data length] == 0) return;
            NSLog(@"stderr: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }];
        __weak __typeof(self) weakSelf = self;
        [self setReadHandler:^(NSData *data) {
            __strong __typeof(self) strongSelf = weakSelf;
            if ([data length] == 0) return;
            [strongSelf didReceiveData:data];
        }];
        [self setDataHandler:^(NSData *content, NSString *charset) {
            __strong __typeof(self) strongSelf = weakSelf;
            [strongSelf handlePipelineMessage:content];
        }];
    }
    return self;
}

- (void)writeData:(NSData *)data {
    [[_stdinPipe fileHandleForWriting] writeData:data];
}

- (void)close {
    [[_stdinPipe fileHandleForReading] closeFile];
    [[_stdinPipe fileHandleForWriting] closeFile];
    [[_stdoutPipe fileHandleForReading] closeFile];
    [[_stdoutPipe fileHandleForWriting] closeFile];
    [[_stderrPipe fileHandleForReading] closeFile];
    [[_stderrPipe fileHandleForWriting] closeFile];
    [[_stdoutPipe fileHandleForReading] setReadabilityHandler:nil];
    [[_stderrPipe fileHandleForReading] setReadabilityHandler:nil];
}

@end

@implementation LSPPipeline (MessageTransport)

NSString *ParsenContentType(NSString *str, NSDictionary **params) {
    NSString *contentType = str;
    NSArray *components = [str componentsSeparatedByString:@";"];
    if ([components count] > 1) {
        contentType = [components objectAtIndex:0];
        if (*params) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            for (NSString *component in [components subarrayWithRange:NSMakeRange(1, [components count] - 1)]) {
                NSArray *keyvalue = [component componentsSeparatedByString:@"="];
                if ([keyvalue count] == 2) {
                    NSString *key = [[keyvalue objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    NSString *value = [[keyvalue objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    if (key && value) {
                        [dict setObject:value forKey:key];
                    }
                }
            }
            *params = [dict copy];
        }
    }
    return contentType;
}

- (void)didReceiveData:(NSData *)data {
    [_buffer appendData:data];
    NSData *remainingData = data;
    do {
        if (_message == NULL) {
            _message = CFHTTPMessageCreateEmpty(NULL, NO);
            NSData *header = [@"HTTP/1.1 200 OK\r\n" dataUsingEncoding:NSUTF8StringEncoding];
            CFHTTPMessageAppendBytes(_message, [header bytes], [header length]);
        }
        CFHTTPMessageAppendBytes(_message, [remainingData bytes], [remainingData length]);
        if (CFHTTPMessageIsHeaderComplete(_message)) {
            NSDictionary *headers = (__bridge_transfer id)CFHTTPMessageCopyAllHeaderFields(_message);
            NSDictionary *contentTypeParams = nil;
            ParsenContentType([headers objectForKey:@"Content-Type"], &contentTypeParams);
            NSString *charset = [contentTypeParams objectForKey:@"charset"] ?: @"utf-8";
            NSUInteger length = (NSUInteger)[[headers objectForKey:@"Content-Length"] integerValue];
            NSData *body = (__bridge_transfer id)CFHTTPMessageCopyBody(_message);
            if ([body length] >= length) {
                NSData *content = [body subdataWithRange:NSMakeRange(0, length)];
                remainingData = [body subdataWithRange:NSMakeRange(length, [body length] - length)];
                [_buffer setData:remainingData];
                CFRelease(_message);
                _message = NULL;
                if (_dataHandler) {
                    _dataHandler(content, charset);
                }
            }
        }
    } while (_message == NULL && [remainingData length]);
}

- (void)sendMessage:(NSData *)data {
    NSString *contentLength = [NSString stringWithFormat:@"Content-Length: %lu\r\n\r\n",
                               (unsigned long)[data length]];
    NSMutableData *messageData = [NSMutableData data];
    [messageData appendData:[contentLength dataUsingEncoding:NSUTF8StringEncoding]];
    [messageData appendData:data];
    [self writeData:messageData];
}

@end

@implementation LSPPipeline (ProtocolTransport)

- (NSError *)_errorForMessage:(NSDictionary *)json {
    NSError *error = nil;
    NSDictionary *jsonError = [json objectForKey:@"error"];
    if (jsonError) {
        NSDictionary *info = nil;
        NSString *message = [jsonError objectForKey:@"message"];
        if (message) {
            info = [NSDictionary dictionaryWithObjectsAndKeys:
                    message, NSLocalizedDescriptionKey, nil];
        }
        error = [NSError errorWithDomain:LSPResponseError code:[[jsonError objectForKey:@"code"] integerValue] userInfo:info];
    }
    return error;
}

- (void)handlePipelineMessage:(NSData *)data {
    NSError *error = nil;
    NSDictionary *message = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (message == nil) {
        NSLog(@"%s error %@",__PRETTY_FUNCTION__, error);
        return;
    }
    NSNumber *messageID = [message objectForKey:@"id"];
    if (messageID != nil) {
        void (^block)(NSDictionary *, NSError *) = [_replyBlocks objectForKey:messageID];
        if (block) {
            NSError *error = [self _errorForMessage:message];
            NSDictionary *result = [message objectForKey:@"result"];
            block(result, error);
            [_replyBlocks removeObjectForKey:messageID];
        }
        if (_log) {
            [self logMessage:message type:@"recv-request"];
        }
    } else {
        if (_notificationMessageHandler) {
            _notificationMessageHandler(message);
        }
        if (_log) {
            [self logMessage:message type:@"recv-notification"];
        }
    }
}

- (void)sendRequest:(NSString *)method params:(NSDictionary *)params withReply:(void (^)(id obj, NSError *error))block {
    _messageID++;
    NSNumber *messageID = [NSNumber numberWithUnsignedInteger:_messageID];
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"2.0", @"jsonrpc",
                             messageID, @"id",
                             method, @"method",
                             params ?: [NSNull  null], @"params",
                             nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:NULL];
    if (data) {
        [_replyBlocks setObject:[block copy] forKey:messageID];
        [self sendMessage:data];
    }
    if (_log) {
        [self logMessage:request type:@"send-request"];
    }
}

- (void)sendNotification:(NSString *)method params:(NSDictionary *)params {
    NSDictionary *request = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"2.0", @"jsonrpc",
                             method, @"method",
                             params ?: [NSNull  null], @"params",
                             nil];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:request options:0 error:&error];
    if (data) {
        [self sendMessage:data];
    }
    if (_log) {
        [self logMessage:request type:@"send-notification"];
    }
}

/** See LspItem at https://github.com/Microsoft/language-server-protocol-inspector  */
- (void)logMessage:(NSDictionary *)message type:(NSString *)type {
    NSDictionary *logItem = [NSDictionary dictionaryWithObjectsAndKeys:
                             type, @"type",
                             message, @"message",
                             [NSNumber numberWithInteger:[[NSDate date] timeIntervalSince1970]], @"timestamp",
                             nil];
    NSData *logData = [NSJSONSerialization dataWithJSONObject:logItem options:0 error:NULL];
    NSString *logString = [[NSString alloc] initWithData:logData encoding:NSUTF8StringEncoding];
    if (logString) {
        [_log appendString:logString];
        [_log appendString:@"\r\n"];
    }
}

@end

@interface LSPDocument : NSObject
@property NSURL *uri;
@property NSMutableString *text;
@property NSString *languageID;
@property NSUInteger version;
@property NSMutableArray *contentChanges;
@end

@implementation LSPDocument

// hmm, maybe it would be better to have a reference to NSTextStorage
- (instancetype)initWithURL:(NSURL *)URL content:(NSString *)text languageID:(NSString *)languageID {
    self = [super init];
    if (self) {
        _uri = [URL copy];
        _text = (text != nil) ? [text mutableCopy] : [NSMutableString string];
        _languageID = [languageID copy];
        _version = 1;
        _contentChanges = [NSMutableArray array];
    }
    return self;
}

- (NSDictionary *)textDocumentIdentifier {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [_uri absoluteString], @"uri",
            nil];
}

- (NSDictionary *)versionedTextDocumentIdentifier {
    // increase version only on "textDocument/didChange" notification
    // and not with every -changeTextInRange:replacementString:.
    _version++;
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [_uri absoluteString], @"uri",
            [NSNumber numberWithUnsignedInteger:_version], @"version",
            nil];
}

- (NSDictionary *)textDocumentItem {
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [_uri absoluteString], @"uri",
            _languageID, @"languageId",
            [NSNumber numberWithUnsignedInteger:_version], @"version",
            _text, @"text",
            nil];
}

- (void)changeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    LSPRange *range = nil;
    if ([replacementString length] == 0) {
        range = [LSPRange range:affectedCharRange inText:_text];
    }
    [_text replaceCharactersInRange:affectedCharRange withString:replacementString];
    if ([replacementString length] > 0) {
        range = [LSPRange range:affectedCharRange inText:_text];
    }
    NSNumber *rangeLength = [NSNumber numberWithUnsignedInteger:[replacementString length]];
    NSDictionary *changeEvent =  [NSDictionary dictionaryWithObjectsAndKeys:
                                  range, @"range",
                                  rangeLength, @"rangeLength",
                                  replacementString, @"text",
                                  nil];
    [_contentChanges addObject:changeEvent];
}

- (NSDictionary *)syncTextDocumentParams:(LSPTextDocumentSyncKind)kind {
    NSDictionary *didChangeTextDocumentParams = nil;
    NSDictionary *textDocument = [self versionedTextDocumentIdentifier];
    NSArray *contentChanges = nil;
    if (kind == LSPTextDocumentSyncKindIncremental) {
        contentChanges = _contentChanges;
    } else if (kind == LSPTextDocumentSyncKindFull) {
        NSDictionary *changeEvent = [NSDictionary dictionaryWithObjectsAndKeys: _text, @"text", nil];
        contentChanges = [NSArray arrayWithObject:changeEvent];
    } 
    didChangeTextDocumentParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                   textDocument, @"textDocument",
                                   contentChanges, @"contentChanges",
                                   nil];
    return didChangeTextDocumentParams;
}

- (void)clearContentChanges {
    [_contentChanges removeAllObjects];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ uri = %@ version = %lu>", [self className], _uri, (unsigned long)_version];
}

@end

@interface LSPClient () {
    BOOL _initialized;
    NSMutableArray<void (^)(NSError *)> *_initializerCallbacks;
    BOOL _shouldTerminate;
    NSMapTable *_terminateObervers;
    NSMutableArray<id<LSPClientObserver>> *_observers;
    NSMutableDictionary<NSURL *, LSPDocument *> *_documents;
    NSNotificationQueue *_documentChangesQueue;
}
@property LSPPipeline *pipeline;
@property NSTask *task;
@end

@implementation LSPClient

/** Used for Coalescing Notifications, where we want to post a notification if a given event occurs at least once, but we want to post no more than one notification even if the event occurs multiple times. */
+ (NSNotificationCenter *)defaultNotificationCenter {
    static id notificationCenter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notificationCenter = [[NSNotificationCenter alloc] init];
    });
    return notificationCenter;
}

+ (instancetype)sharedBashServer {
    static id sharedServer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *plugInsPath = [[NSBundle bundleForClass:[self class]] builtInPlugInsPath];
        NSString *bashBundle = [plugInsPath stringByAppendingPathComponent:@"bash-language-server.bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bashBundle];
        sharedServer =  [[[self class] alloc] initWithPath:[bundle executablePath] arguments:[NSArray arrayWithObjects:@"start", nil] currentDirectoryPath:[bundle resourcePath] languageID:@"shellscript"];
    });
    return sharedServer;
}

+ (instancetype)sharedHTMLServer {
    static id sharedServer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *plugInsPath = [[NSBundle bundleForClass:[self class]] builtInPlugInsPath];
        NSString *bundlePath = [plugInsPath stringByAppendingPathComponent:@"vscode-html-languageserver.bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        NSString *nodeAppPath = [[bundle resourcePath] stringByAppendingPathComponent:@"node_modules/vscode-html-languageserver-bin/htmlServerMain.js"];
        sharedServer = [[[self class] alloc] initWithPath:[bundle executablePath] arguments:[NSArray arrayWithObjects:nodeAppPath, @"--stdio", nil] currentDirectoryPath:[bundle resourcePath] languageID:@"html"];
    });
    return sharedServer;
}

- (instancetype)initWithPath:(NSString *)path arguments:(NSArray<NSString *> *)arguments currentDirectoryPath:(NSString *)currentDirectoryPath languageID:(NSString *)languageID
{
    self = [super init];
    if (self) {
        __weak __typeof(self) weakSelf = self;
        _terminateObervers = [NSMapTable weakToStrongObjectsMapTable];  // entries are not necessarily purged right away when the weak key is reclaimed
        _observers = [NSMutableArray array];
        _documents = [NSMutableDictionary dictionary];
        _documentChangesQueue = [[NSNotificationQueue alloc] initWithNotificationCenter:[[self class] defaultNotificationCenter]];
        [[[self class] defaultNotificationCenter] addObserver:self selector:@selector(_documentDidChange:) name:LSPDocumentDidChangeNotification object:self];
        _languageID = languageID;
        _pipeline = [[LSPPipeline alloc] init];
        [_pipeline setNotificationMessageHandler:^(NSDictionary *message) {
            __strong __typeof(self) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf handleNotificationMessage:message];
            });
        }];
        _task = [[NSTask alloc] init];
        [_task setStandardInput:[_pipeline stdinPipe]];
        [_task setStandardOutput:[_pipeline stdoutPipe]];
        [_task setStandardError:[_pipeline stderrPipe]];
        if (currentDirectoryPath) {
            [_task setCurrentDirectoryPath:currentDirectoryPath];
        }
        [_task setLaunchPath:path];
        [_task setArguments:arguments];
        [_task setTerminationHandler:^(NSTask *task) {
            __strong __typeof(self) strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                [strongSelf handleTermination];
            });
        }];
        [_task launch];
    }
    return self;
}

#pragma mark Termination

- (void)terminate {
    if ([_task isRunning]) {
        _shouldTerminate = YES;
        [_task terminate];
    }
}

- (void)handleTermination {
    [[self pipeline] close];
    _initialized = NO;
    _initializerCallbacks = nil;
    [_documents removeAllObjects];
    if (_shouldTerminate == NO) {
        NSString *currentDirectoryPath = [_task currentDirectoryPath];
        NSString *path = [_task launchPath];
        NSArray *arguments = [_task arguments];
        void (^terminationHandler)(NSTask *) = [_task terminationHandler];
        _pipeline = [[LSPPipeline alloc] init];
        _task = [[NSTask alloc] init];
        [_task setStandardInput:[_pipeline stdinPipe]];
        [_task setStandardOutput:[_pipeline stdoutPipe]];
        [_task setStandardError:[_pipeline stderrPipe]];
        if (currentDirectoryPath) {
            [_task setCurrentDirectoryPath:currentDirectoryPath];
        }
        [_task setLaunchPath:path];
        [_task setArguments:arguments];
        [_task setTerminationHandler:terminationHandler];
        [_task launch];
        for (void (^block)(LSPClient *client) in [_terminateObervers objectEnumerator]) {
            block(self);
        }
    }
}

- (void)addTerminationObserver:(id)observer block:(void (^)(LSPClient *client))block {
    [_terminateObervers setObject:[block copy] forKey:observer];
}

- (void)removeTerminationObserver:(id)observer {
    [_terminateObervers removeObjectForKey:observer];
}

#pragma mark Observers

- (void)addObserver:(id<LSPClientObserver>)observer {
    [_observers addObject:observer];
}

- (void)removeObserver:(id<LSPClientObserver>)observer {
    [_observers removeObject:observer];
}

#pragma mark Notification Message

- (void)handleRequestMessage:(NSDictionary *)requestMessage {
    NSNumber *method = [requestMessage objectForKey:@"method"];
    if ([method isEqual:@"window/showMessageRequest"]) {
        NSLog(@"window/showMessageRequest %@", requestMessage);
    }
}
- (void)handleNotificationMessage:(NSDictionary *)notificaton {
    NSNumber *method = [notificaton objectForKey:@"method"];
    NSDictionary *params = [notificaton objectForKey:@"params"];
    LSPMessageType messageType = 0;
    NSString *message = nil;
    NSString *uri = nil;
    NSURL *url = nil;
    NSArray *diagnostics = nil;
    if ([params isKindOfClass:[NSDictionary class]]) {
        // method: window
        messageType = [[params objectForKey:@"type"] integerValue];
        message = [params objectForKey:@"message"];
        // method: publishDiagnostics
        uri = [params objectForKey:@"uri"];
        url = [NSURL URLWithString:uri];
        diagnostics = [LSPDiagnostic diagnosticsFromArray:[params objectForKey:@"diagnostics"]];
    }
    for (id<LSPClientObserver> observer in _observers) {
        if ([method isEqual:@"window/logMessage"]) {
            if ([observer respondsToSelector:@selector(languageServer:logMessage:type:)]) {
                [observer languageServer:self logMessage:message type:messageType];
            }
        } else if ([method isEqual:@"window/showMessage"]) {
            if ([observer respondsToSelector:@selector(languageServer:showMessage:type:)]) {
                [observer languageServer:self showMessage:message type:messageType];
            }
        } else if ([method isEqual:@"telemetry/event"]) {
            if ([observer respondsToSelector:@selector(languageServer:telemetryEvent:)]) {
                [observer languageServer:self telemetryEvent:params];
            }
        } else if ([method isEqual:@"textDocument/publishDiagnostics"]) {
            if ([observer respondsToSelector:@selector(languageServer:document:diagnostics:)]) {
                [observer languageServer:self document:url diagnostics:diagnostics];
            }
        }
    }
}

#pragma mark General

- (void)initialWithCompletionHandler:(void (^)(NSError *error))completionHandler {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    @synchronized (self) {
        if (_initialized) {
            if (completionHandler) {
                completionHandler(nil);
            }
        } else {
            if (_initializerCallbacks == nil) {
                // Only send one initialize request
                [self _initialize];
                _initializerCallbacks = [NSMutableArray array];
            }
            // All completionHandler will be answered in the initialize response
            [_initializerCallbacks addObject:completionHandler];
        }
    }
}

- (void)_initialize {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSNumber *pid = [NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]];
    NSDictionary *capabilities = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNull null], @"workspace",
                                  [NSNull null], @"textDocument",
                                  [NSNull null], @"experimental",
                                  nil];
    [params setObject:pid forKey:@"processId"];
    [params setObject:[NSNull null] forKey:@"rootPath"];
    [params setObject:[NSNull null] forKey:@"rootURI"];
    [params setObject:[NSNull null] forKey:@"initializationOptions"];
    [params setObject:capabilities forKey:@"capabilities"];
    [params setObject:@"verbose" forKey:@"trace"];
    [params setObject:[NSNull null] forKey:@"workspaceFolders"];
    
    [_pipeline sendRequest:@"initialize" params:params withReply:^(NSDictionary *obj, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self initializeResponseWithObject:obj error:error];
        });
    }];
}

- (void)initializeResponseWithObject:(id)obj error:(NSError *)error {
    self->_initialized = (error == nil);
    NSDictionary *capabilities = [obj objectForKey:@"capabilities"];
    id textDocumentSyncValue = [capabilities objectForKey:@"textDocumentSync"];
    if ([textDocumentSyncValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *syncOptions = textDocumentSyncValue;
        self->_textDocumentSync.openClose = [[syncOptions objectForKey:@"openClose"] boolValue];
        self->_textDocumentSync.change = [[syncOptions objectForKey:@"change"] integerValue];
        self->_textDocumentSync.willSave = [[syncOptions objectForKey:@"willSave"] boolValue];
        self->_textDocumentSync.willSaveWaitUntil = [[syncOptions objectForKey:@"willSaveWaitUntil"] boolValue];
        NSDictionary *saveOptions = [syncOptions objectForKey:@"save"];
        if ([saveOptions isKindOfClass:[NSDictionary class]]) {
            self->_textDocumentSync.saveOptionIncludeText =  [[saveOptions objectForKey:@"includeText"] boolValue];
        }
    } else if ([textDocumentSyncValue isKindOfClass:[NSNumber class]]) {
        self->_textDocumentSync.change = [textDocumentSyncValue integerValue];
        switch (self->_textDocumentSync.change) {
            case LSPTextDocumentSyncKindNone:
                break;
            case LSPTextDocumentSyncKindFull:
                self->_textDocumentSync.openClose = YES;
                break;
            case LSPTextDocumentSyncKindIncremental:
                self->_textDocumentSync.openClose = YES;
                break;
        }
    }
    self->_hoverProvider = [[capabilities objectForKey:@"hoverProvider"] boolValue];
    id completionProvider = [capabilities objectForKey:@"completionProvider"];
    if ([completionProvider isKindOfClass:[NSDictionary class]]) {
        NSDictionary *completionDict = completionProvider;
        self->_completionProvider = YES;
        self->_completionResolveProvider = [[completionDict objectForKey:@"resolveProvider"] boolValue];
        self->_completionTriggerCharacters = [completionDict objectForKey:@"triggerCharacters"];
    }
    NSDictionary *signatureHelpProvider = [capabilities objectForKey:@"signatureHelpProvider"];
    if ([signatureHelpProvider isKindOfClass:[NSDictionary class]]) {
        self->_signatureHelpProvider = YES;
        _signatureHelpProviderTriggerCharacters = [signatureHelpProvider objectForKey:@"triggerCharacters"];
    }
    self->_definitionProvider = [[capabilities objectForKey:@"definitionProvider"] boolValue];
    //self->_typeDefinitionProvider; unsure about TextDocumentRegistrationOptions
    //self->_implementationProvider; unsure about TextDocumentRegistrationOptions
    self->_referencesProvider = [[capabilities objectForKey:@"referencesProvider"] boolValue];
    self->_documentHighlightProvider = [[capabilities objectForKey:@"documentHighlightProvider"] boolValue];
    self->_documentSymbolProvider = [[capabilities objectForKey:@"documentSymbolProvider"] boolValue];
    self->_workspaceSymbolProvider = [[capabilities objectForKey:@"workspaceSymbolProvider"] boolValue];
    //self->_codeActionProvider; to many CodeActionOptions right now
    NSDictionary *codeLensProvider = [capabilities objectForKey:@"codeLensProvider"];
    if ([codeLensProvider isKindOfClass:[NSDictionary class]]) {
        self->_codeLensProvider = YES;
        self->_codeLensResolveProvider = [[codeLensProvider objectForKey:@"resolveProvider"] boolValue];
    }
    self->_documentFormattingProvider = [[capabilities objectForKey:@"documentFormattingProvider"] boolValue];
    self->_documentRangeFormattingProvider = [[capabilities objectForKey:@"documentRangeFormattingProvider"] boolValue];
    NSDictionary *documentOnTypeFormattingProvider = [capabilities objectForKey:@"documentOnTypeFormattingProvider"];
    if ([documentOnTypeFormattingProvider isKindOfClass:[NSDictionary class]]) {
        self->_documentOnTypeFormattingProvider = YES;
        self->_documentOnTypeFormattingFirstTriggerCharacter = [documentOnTypeFormattingProvider objectForKey:@"firstTriggerCharacter"];
        self->_documentOnTypeFormattingMoreTriggerCharacter = [documentOnTypeFormattingProvider objectForKey:@"moreTriggerCharacter"];
    }
    NSDictionary *renameProvider = [capabilities objectForKey:@"renameProvider"];
    if (renameProvider) {
        if ([renameProvider isKindOfClass:[NSDictionary class]]) {
            self->_renameProvider = YES;
            self->_renamePrepareProvider = [[capabilities objectForKey:@"prepareProvider"] boolValue];
        } else if ([renameProvider isKindOfClass:[NSNumber class]]) {
            self->_renameProvider = [[capabilities objectForKey:@"renameProvider"] boolValue];
        }
    }
    NSDictionary *documentLinkProvider = [capabilities objectForKey:@"documentLinkProvider"];
    if ([documentLinkProvider isKindOfClass:[NSDictionary class]]) {
        self->_documentLinkProvider = YES;
        _documentLinkProviderResolveProvider = [[documentLinkProvider objectForKey:@"resolveProvider"] boolValue];
    }
    NSDictionary *colorProvider = [capabilities objectForKey:@"colorProvider"];
    if ([colorProvider isKindOfClass:[NSDictionary class]]) {
        self->_colorProvider = YES;
        _colorProviderDynamicRegistration = [[colorProvider objectForKey:@"dynamicRegistration"] boolValue];
    }
    self->_foldingRangeProvider = [[capabilities objectForKey:@"foldingRangeProvider"] boolValue];
    NSDictionary *executeCommandProvider = [capabilities objectForKey:@"executeCommandProvider"];
    if ([executeCommandProvider isKindOfClass:[NSDictionary class]]) {
        self->_executeCommandProvider = YES;
        self->_executeCommandCommands = [executeCommandProvider objectForKey:@"commands"];
    }
    
    for (void (^completionHandler)(NSError *) in _initializerCallbacks) {
        completionHandler(error);
    }
    _initializerCallbacks = nil;
}

- (void)shutdownWithCompletionHandler:(void (^)(NSError *error))completionHandler  {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    
    [_pipeline sendRequest:@"shutdown" params:nil withReply:^(id obj, NSError *error) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(error);
            });
        }
    }];
}

- (void)exit {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    // The one notification where we don't check for if (_initialize == NO) return;
    // This will allow the exit of a server without an initialize request.
    _shouldTerminate = YES;
    pid_t pid = [_task processIdentifier];
    [_pipeline sendNotification:@"exit" params:nil];
    waitpid(pid, NULL, 0);
}

#pragma mark Text Synchronization

- (void)documentDidOpen:(NSURL *)url content:(NSString *)text {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    NSAssert(([_documents objectForKey:url] == nil), @"An open notification must not be sent more than once without a corresponding close notification send before. This means open and close notification must be balanced and the max open count for a particular textDocument is one.");
    
    LSPDocument *document = [[LSPDocument alloc] initWithURL:url content:text languageID:_languageID];
    [_documents setObject:document forKey:url];
    if (_textDocumentSync.openClose == NO) {
        return;
    }
    NSDictionary *documentParams = [document textDocumentItem];
    [_pipeline sendNotification:@"textDocument/didOpen" params:[NSDictionary dictionaryWithObjectsAndKeys:documentParams, @"textDocument", nil]];
}

- (void)document:(NSURL *)url changeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    [document changeTextInRange:affectedCharRange replacementString:replacementString];
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:document, LSPDocumentUserInfoKey, nil];
    NSNotification *changeNotification = [NSNotification notificationWithName:LSPDocumentDidChangeNotification object:self userInfo:userInfo];
    // It would be very expensive (and not very useful) to update the document after
    // each character the user types, especially if the user types quickly.
    // We queue a notification, with coalescing turned on and a posting style
    // of NSPostWhenIdle after each character typed.
    // When the user stops typing, the single notification in the queue (due to coalescing)
    // is posted when the run loop enters its wait state and the language server
    // "textDocument/didChange" notifcation is send.
    [_documentChangesQueue enqueueNotification:changeNotification
                                  postingStyle:NSPostWhenIdle
                                  coalesceMask:NSNotificationCoalescingOnName
                                      forModes:nil];
}

- (void)documentDidChange:(NSURL *)url {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:document, LSPDocumentUserInfoKey, nil];
    NSNotification *changeNotification = [NSNotification notificationWithName:LSPDocumentDidChangeNotification object:self userInfo:userInfo];
    [_documentChangesQueue enqueueNotification:changeNotification
                                  postingStyle:NSPostNow
                                  coalesceMask:NSNotificationCoalescingOnName
                                      forModes:nil];
}

- (void)_documentDidChange:(NSNotification *)notification {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    
    LSPDocument *document = [[notification userInfo] objectForKey:LSPDocumentUserInfoKey];
    if (_textDocumentSync.change == LSPTextDocumentSyncKindNone) {
        [document clearContentChanges];
        return;
    }
    NSDictionary *documentParams = [document syncTextDocumentParams:_textDocumentSync.change];
    [_pipeline sendNotification:@"textDocument/didChange" params:documentParams];
    [document clearContentChanges];
}

- (void)documentWillSave:(NSURL *)url {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    NSDictionary *documentParams = [NSDictionary dictionaryWithObjectsAndKeys:[document textDocumentIdentifier], @"textDocument", nil];
    [_pipeline sendNotification:@"textDocument/willSave" params:documentParams];
}

- (void)documentDidSave:(NSURL *)url {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    NSMutableDictionary *documentParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:[document textDocumentIdentifier], @"textDocument", nil];;
    if (_textDocumentSync.saveOptionIncludeText) {
        [documentParams setObject:[document text] forKey:@"text"];
    }
    [_pipeline sendNotification:@"textDocument/didSave" params:documentParams];
}

- (void)documentDidClose:(NSURL *)url {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    NSDictionary *documentParams = [NSDictionary dictionaryWithObjectsAndKeys:[document textDocumentIdentifier], @"textDocument", nil];
    [_pipeline sendNotification:@"textDocument/didClose" params:documentParams];
    [_documents removeObjectForKey:url];
}

#pragma mark Language Features

- (void)documentCompletion:(NSURL *)url inText:(NSString *)string forCharacterAtIndex:(NSUInteger)characterIndex completionHandler:(void (^)(NSArray<LSPCompletionItem *> *completionList, BOOL isIncomplete, NSError *error))completionHandler {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    LSPPosition *position = [LSPPosition positionForCharacterAtIndex:characterIndex inText:string];
    NSDictionary *completionParams = [NSDictionary dictionaryWithObjectsAndKeys:[document textDocumentIdentifier], @"textDocument", [position params], @"position", nil];
    [_pipeline sendRequest:@"textDocument/completion" params:completionParams withReply:^(id obj, NSError *error) {
        BOOL isIncomplete = NO;
        NSArray *items = nil;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = obj;
            isIncomplete = [[dict objectForKey:@"isIncomplete"] boolValue];
            items = [dict objectForKey:@"items"];
        } else if ([obj isKindOfClass:[NSArray class]]) {
            items = obj;
        }
        NSMutableArray *completionList = [NSMutableArray arrayWithCapacity:[items count]];
        for (NSDictionary *item in items) {
            LSPCompletionItem *completionItem = [[LSPCompletionItem alloc] initWithDictionary:item];
            if (completionItem) {
                [completionList addObject:completionItem];
            }
        }
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler([completionList copy], isIncomplete, error);
            });
        }
    }];
}
    
- (void)documentSymbol:(NSURL *)url completionHandler:(void (^)(NSArray *symbols, NSError *error))completionHandler  {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    NSDictionary *symbolParams = [NSDictionary dictionaryWithObjectsAndKeys:[document textDocumentIdentifier], @"textDocument", nil];
    [_pipeline sendRequest:@"textDocument/documentSymbol" params:symbolParams withReply:^(NSDictionary *obj, NSError *error) {
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler((id)obj, error);
            });
        }
    }];
}

+ (NSArray<LSPDocumentHighlight *> *)documentHighlightFromArray:(NSArray *)array inText:(NSString *)string {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[array count]];
    for (NSDictionary *dict in array) {
        if ([dict isKindOfClass:[NSDictionary class]]) {
            LSPDocumentHighlight *highlight = [[self class] documentHighlightFromDictionary:dict inText:string];
            if (highlight) {
                [result addObject:highlight];
            }
        }
    }
    return [result copy];
}

+ (LSPDocumentHighlight *)documentHighlightFromDictionary:(NSDictionary *)dict inText:(NSString *)string {
    LSPRange *lspRange = [LSPRange rangeFromDictionary:[dict objectForKey:@"range"]];
    NSRange range = [lspRange convertToRangeInText:string];
    LSPDocumentHighlightKind kind = LSPDocumentHighlightKindText;
    if ([dict objectForKey:@"kind"]) {
        kind = [[dict objectForKey:@"kind"] integerValue];
    }
    return [[LSPDocumentHighlight alloc] initWithRange:range kind:kind];
}

- (void)documentHighlight:(NSURL *)url inText:(NSString *)string forCharacterAtIndex:(NSUInteger)characterIndex completionHandler:(void (^)(NSArray<LSPDocumentHighlight *> *, NSError *error))completionHandler  {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    LSPPosition *position = [LSPPosition positionForCharacterAtIndex:characterIndex inText:string];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[document textDocumentIdentifier] forKey:@"textDocument"];
    [params setObject:[position params] forKey:@"position"];
    [_pipeline sendRequest:@"textDocument/documentHighlight" params:params withReply:^(id obj, NSError *error) {
        NSArray *documentHighlights = nil;
        if ([obj isKindOfClass:[NSArray class]]) {
            documentHighlights = [[self class] documentHighlightFromArray:obj inText:string];
        }
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(documentHighlights, error);
            });
        }
    }];
}

- (void)documentHoverWithContentsOfURL:(NSURL *)url inText:(NSString *)string forCharacterAtIndex:(NSUInteger)characterIndex completionHandler:(void (^)(NSDictionary *dict, NSError *error))completionHandler  {
    NSAssert([NSThread isMainThread], @"This method must be invoked on main thread");
    if (_initialized == NO) return;
    LSPDocument *document = [_documents objectForKey:url];
    NSAssert((document != nil), @"An open notification must be send before.");
    
    LSPPosition *position = [LSPPosition positionForCharacterAtIndex:characterIndex inText:string];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[document textDocumentIdentifier] forKey:@"textDocument"];
    [params setObject:[position params] forKey:@"position"];
    [_pipeline sendRequest:@"textDocument/hover" params:params withReply:^(id obj, NSError *error) {
        NSDictionary *result = nil;
        if ([obj isKindOfClass:[NSDictionary class]]) {
            result = obj;
        }
        if (completionHandler) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionHandler(result, error);
            });
        }
    }];
}

@end
