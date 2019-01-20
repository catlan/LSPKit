//
//  AppDelegate.m
//  Script Editor
//
//  Created by Christopher Atlan on 13.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "DocumentController.h"
#import <LSPKit/LSPKit.h>

@interface AppDelegate () <LSPClientObserver>

@end

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [DocumentController sharedDocumentController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[LSPClient sharedBashServer] addObserver:self];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)languageServer:(LSPClient *)client logMessage:(NSString *)message type:(LSPMessageType)type {
    switch (type) {
        case LSPMessageTypeError:
            NSLog(@"ERROR %@", message);
            break;
        case LSPMessageTypeWarning:
            NSLog(@"WARNING %@", message);
            break;
        case LSPMessageTypeInfo:
            NSLog(@"INFO %@", message);
            break;
        case LSPMessageTypeLog:
            NSLog(@"LOG %@", message);
            break;
    }
}

- (void)languageServer:(LSPClient *)client showMessage:(NSString *)message type:(LSPMessageType)type {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    if (type == LSPMessageTypeWarning) {
        alert.alertStyle = NSAlertStyleWarning;
    } else if (type == LSPMessageTypeError) {
        alert.alertStyle = NSAlertStyleCritical;
    } else if (type == LSPMessageTypeInfo) {
        alert.alertStyle = NSAlertStyleInformational;
    }
    [alert runModal];
}


@end
