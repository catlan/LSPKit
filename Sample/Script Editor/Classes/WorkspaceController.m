//
//  WorkspaceController.m
//  Script Editor
//
//  Created by Christopher Atlan on 20.01.19.
//  Copyright © 2019 Letter Opener GmbH. All rights reserved.
//

#import "WorkspaceController.h"

@interface WorkspaceController () {
    NSMutableArray *_workspaces;
}
@end

@implementation WorkspaceController

+ (__kindof WorkspaceController *)sharedWorkspaceController {
    static id sharedWorkspaceController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedWorkspaceController = [[WorkspaceController alloc] init];
    });
    return sharedWorkspaceController;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _workspaces = [NSMutableArray array];
    }
    return self;
}

- (NSArray<Workspace *> *)workspaces {
    return [_workspaces copy];
}

- (nullable __kindof Workspace *)workspaceForURL:(NSURL *)url {
    for (Workspace *workspace in _workspaces) {
        NSString *workspacePath = [[workspace URL] path];
        if ([[url path] hasPrefix:workspacePath]) {
            return workspace;
        }
    }
    return nil;
}

- (nullable __kindof Workspace *)workspaceForDocument:(NSDocument *)document {
    for (Workspace *workspace in _workspaces) {
        for (NSDocument *workspaceDocument in [workspace documents]) {
            if ([workspaceDocument isEqual:document]) {
                return workspace;
            }
        }
    }
    return nil;
}

- (void)addWorkspace:(Workspace *)workspace {
    if ([_workspaces containsObject:workspace] == NO) {
        [_workspaces addObject:workspace];
        // Sorting so -workspaceForURL: can find to nearest path
        [_workspaces sortUsingComparator:^NSComparisonResult(Workspace *obj1, Workspace *obj2) {
            NSComparisonResult result = [[[obj1 URL] path] compare:[[obj2 URL] path]];
            return result * -1;
        }];
    }
}

- (void)removeWorkspace:(Workspace *)workspace {
    [_workspaces removeObject:workspace];
}

- (nullable __kindof Workspace *)makeWorkspaceWithContentsOfURL:(NSURL *)url error:(NSError **)outError {
    BOOL directory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:[url path] isDirectory:&directory] && directory) {
        return [[Workspace alloc] initWithURL:url];
    }
    return nil;
}

@end


@implementation Workspace {
    NSMutableArray *_documents;
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if (self) {
        _URL = URL;
        _documents = [NSMutableArray array];
    }
    return self;
}

- (NSArray<__kindof NSDocument *> *)documents {
    return [_documents copy];
}

- (void)addDocument:(NSDocument *)document {
    if ([_documents containsObject:document] == NO) {
        [_documents addObject:document];
    }
}

- (void)removeDocument:(NSDocument *)document {
    [_documents removeObject:document];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ URL = %@ documents = %@>", [self className], _URL, _documents];
}

@end
