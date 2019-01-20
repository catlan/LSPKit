//
//  DocumentController.m
//  Script Editor
//
//  Created by Christopher Atlan on 20.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "DocumentController.h"

#import "WorkspaceController.h"

@implementation DocumentController

- (void)addDocument:(NSDocument *)document {
    [super addDocument:document];
}

- (void)removeDocument:(NSDocument *)document {
    [super removeDocument:document];
    WorkspaceController *workspaceController = [WorkspaceController sharedWorkspaceController];
    Workspace *workspace = [workspaceController workspaceForDocument:document];
    [workspace removeDocument:document];
    if ([[workspace documents] count] == 0) {
        [workspaceController removeWorkspace:workspace];
    }
}

- (void)openDocumentWithContentsOfURL:(NSURL *)url display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {
    [super openDocumentWithContentsOfURL:url display:displayDocument completionHandler:^(NSDocument *document, BOOL displayDocument, NSError *error) {
        if (document) {
            NSURL *baseURL = [url URLByDeletingLastPathComponent];
            WorkspaceController *workspaceController = [WorkspaceController sharedWorkspaceController];
            Workspace *workspace = [workspaceController workspaceForURL:baseURL];
            if (workspace == nil) {
                workspace = [workspaceController makeWorkspaceWithContentsOfURL:baseURL error:NULL];
                [workspaceController addWorkspace:workspace];
            }
            [workspace addDocument:document];
        }
        if (completionHandler) {
            completionHandler(document, displayDocument, error);
        }
    }];
}

- (void)reopenDocumentForURL:(NSURL *)urlOrNil withContentsOfURL:(NSURL *)contentsURL display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler {
    [super reopenDocumentForURL:urlOrNil withContentsOfURL:contentsURL display:displayDocument completionHandler:^(NSDocument *document, BOOL displayDocument, NSError *error) {
        if (document) {
            NSURL *baseURL = [urlOrNil URLByDeletingLastPathComponent];
            WorkspaceController *workspaceController = [WorkspaceController sharedWorkspaceController];
            Workspace *workspace = [workspaceController workspaceForURL:baseURL];
            if (workspace == nil) {
                workspace = [workspaceController makeWorkspaceWithContentsOfURL:baseURL error:NULL];
                [workspaceController addWorkspace:workspace];
            }
            [workspace addDocument:document];
        }
        if (completionHandler) {
            completionHandler(document, displayDocument, error);
        }
    }];
}

@end
