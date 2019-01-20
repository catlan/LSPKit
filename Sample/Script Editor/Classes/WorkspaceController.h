//
//  WorkspaceController.h
//  Script Editor
//
//  Created by Christopher Atlan on 20.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import <AppKit/AppKit.h>

@class Workspace;

@interface WorkspaceController : NSObject

@property (class, readonly, strong) __kindof WorkspaceController *sharedWorkspaceController;

/* Return an array of all open documents.
 */
@property (readonly, copy) NSArray<__kindof Workspace *> *workspaces;

- (nullable __kindof Workspace *)workspaceForURL:(NSURL *)url;

- (nullable __kindof Workspace *)workspaceForDocument:(NSDocument *)document;

- (void)addWorkspace:(Workspace *)workspace;
- (void)removeWorkspace:(Workspace *)workspace;

- (nullable __kindof Workspace *)makeWorkspaceWithContentsOfURL:(NSURL *)url error:(NSError **)outError;

@end

@interface Workspace : NSObject

@property (readonly, copy) NSURL *URL;

- (instancetype)initWithURL:(NSURL *)URL;

/* Return an array of all open documents.
 */
@property (readonly, copy) NSArray<__kindof NSDocument *> *documents;

/* Add or remove a document from the list of open documents. You can override these methods if your application needs to customize what is done when documents are opened and closed. -addDocument is invoked by the default implementations of all NSDocumentController methods whose names start with "open." Your application can invoke -addDocument: manually if it creates a document using something other than one of NSDocument's "open" methods. -removeDocument is invoked by the default implementation of -[NSDocument close].
 */
- (void)addDocument:(NSDocument *)document;
- (void)removeDocument:(NSDocument *)document;

@end
