//
//  ViewController.m
//  ClearUnusedClasses
//
//  Created by ljh on 15/3/27.
//  Copyright (c) 2015年 SY. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController
{
    NSDictionary* objects;
    NSString* projectDirPath;
    
    NSMutableArray* unusedClassNames;
    NSMutableDictionary* classNames;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    classNames = [NSMutableDictionary dictionary];
}

- (IBAction)beginSearch:(id)sender {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        NSString* path = _textField.stringValue;
        if([path hasSuffix:@".xcodeproj"] == NO)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert* alert = [NSAlert alertWithError:[NSError errorWithDomain:@"请输入 xcodeproj 路径" code:-1 userInfo:nil]];
                [alert beginSheetModalForWindow:[NSApplication sharedApplication].keyWindow completionHandler:nil];
            });
            return;
        }
        NSString* projectPath = [path stringByAppendingPathComponent:@"project.pbxproj"];
        
        NSDictionary* projectDic = [NSDictionary dictionaryWithContentsOfFile:projectPath];
        
        NSString* rootObject = projectDic[@"rootObject"];
        objects = projectDic[@"objects"];
        
        NSDictionary* mainInfo = objects[rootObject];
        
        
        NSString* mainGroupKey = mainInfo[@"mainGroup"];
        
        NSDictionary* mainGroupDic = objects[mainGroupKey];
        
        projectDirPath = [path stringByDeletingLastPathComponent];
        
        [self findClassPathWithDir:projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
        [self checkClassPathWithDir:projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resultTextView.string = @"开始遍历修改xcodeproj文件。。。会比较慢";
        });
        
        
        NSArray* imageNames = [classNames.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* obj1, NSString* obj2) {
            return [obj1 compare:obj2];
        }];
        
        NSString* projectContent = [NSString stringWithContentsOfFile:projectPath encoding:NSUTF8StringEncoding error:nil];
        NSMutableArray* projectContentArray = [NSMutableArray arrayWithArray:[projectContent componentsSeparatedByString:@"\n"]];
        
        NSArray* deleteImages = classNames.allValues;
        
        for (NSDictionary* classInfo in deleteImages) {
            
            NSArray* classKeys = classInfo[@"keys"];
            NSArray* classPaths = classInfo[@"paths"];
            
            BOOL isHasMFile = NO;
            for (NSString* path in classPaths) {
                if([path.pathExtension isEqualToString:@"m"])
                {
                    isHasMFile = YES;
                }
            }
            if(isHasMFile == NO)
                continue;
            
            for (NSString* key in classKeys) {
                [projectContentArray enumerateObjectsUsingBlock:^(NSString* obj, NSUInteger idx, BOOL *stop) {
                    if([obj containsString:key])
                    {
                        [projectContentArray removeObjectAtIndex:idx];
                    }
                }];
            }
            

            for (NSString* path in classPaths) {
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            }
        }
        
        projectContent = [projectContentArray componentsJoinedByString:@"\n"];
        
        NSError* error = nil;
        [projectContent writeToFile:projectPath atomically:YES encoding:NSUTF8StringEncoding error:&error];
        if(error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert* alert = [NSAlert alertWithError:error];
                [alert beginSheetModalForWindow:[NSApplication sharedApplication].keyWindow completionHandler:nil];
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(imageNames.count)
            {
                self.resultTextView.string = [imageNames componentsJoinedByString:@"\n"];
            }
            else
            {
                self.resultTextView.string = @"你的类文件代码里面都有用到";
            }
        });
    });
}
-(void)findClassPathWithDir:(NSString*)dir PBXGroup:(NSDictionary*)PBXGroup key:(NSString*)fromKey
{
    NSArray* children = PBXGroup[@"children"];
    NSString* path = PBXGroup[@"path"];
    NSString* sourceTree = PBXGroup[@"sourceTree"];
    if(path.length > 0)
    {
        if([sourceTree isEqualToString:@"<group>"])
        {
            dir = [dir stringByAppendingPathComponent:path];
        }
        else if([sourceTree isEqualToString:@"SOURCE_ROOT"])
        {
            dir = [projectDirPath stringByAppendingPathComponent:path];
        }
    }
    if(children.count == 0)
    {
        NSString*pathExtension =  dir.pathExtension;
        if([pathExtension isEqualToString:@"m"] || [pathExtension isEqualToString:@"xib"] || [pathExtension isEqualToString:@"h"] || [pathExtension isEqualToString:@"mm"])
        {
            NSString* fileName = dir.lastPathComponent.stringByDeletingPathExtension;
            NSMutableDictionary* classInfo = classNames[fileName];
            if(classInfo == nil)
            {
                classInfo = [NSMutableDictionary dictionary];
                classNames[fileName] = classInfo;
                
                classInfo[@"paths"] = [NSMutableArray array];
                classInfo[@"keys"] = [NSMutableArray array];
            }
            [classInfo[@"paths"] addObject:dir];
            [classInfo[@"keys"] addObject:fromKey];
        }
    }
    else
    {
        for (NSString* key in children) {
            NSDictionary* childrenDic = objects[key];
            [self findClassPathWithDir:dir PBXGroup:childrenDic key:key];
        }
    }
}

-(void)checkClassPathWithDir:(NSString*)dir PBXGroup:(NSDictionary*)PBXGroup key:(NSString*)fromKey
{
    NSArray* children = PBXGroup[@"children"];
    NSString* path = PBXGroup[@"path"];
    NSString* sourceTree = PBXGroup[@"sourceTree"];
    if(path.length > 0)
    {
        if([sourceTree isEqualToString:@"<group>"])
        {
            dir = [dir stringByAppendingPathComponent:path];
        }
        else if([sourceTree isEqualToString:@"SOURCE_ROOT"])
        {
            dir = [projectDirPath stringByAppendingPathComponent:path];
        }
    }
    if(children.count == 0)
    {
        NSString*pathExtension =  dir.pathExtension;
        if([pathExtension isEqualToString:@"m"] || [pathExtension isEqualToString:@"h"] || [pathExtension isEqualToString:@"pch"] || [pathExtension isEqualToString:@"mm"] || [pathExtension isEqualToString:@"xib"])
        {
            [self checkClassWithCodePath:dir];
        }
    }
    else
    {
        for (NSString* key in children) {
            NSDictionary* childrenDic = objects[key];
            [self checkClassPathWithDir:dir PBXGroup:childrenDic key:key];
        }
    }

}
-(void)checkClassWithCodePath:(NSString*)mPath
{
    NSString* mFileName = mPath.lastPathComponent.stringByDeletingPathExtension;
    NSString* contentFile = [NSString stringWithContentsOfFile:mPath encoding:NSUTF8StringEncoding error:nil];
    if(contentFile.length == 0)
        return;
    
    NSString *regularStr = @"\"(\\\\\"|[^\"^\\s]|[\\r\\n])+\"";
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:0 error:nil];
    NSArray* matches = [regex matchesInString:contentFile options:0 range:NSMakeRange(0, contentFile.length)];
    
    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = [match range];
        range.location += 1;
        range.length -=2;
        NSString* subStr = [contentFile substringWithRange:range];
        NSString* fileName = subStr.stringByDeletingPathExtension;
        if([fileName isEqualToString:mFileName])
        {
            continue;
        }
        [classNames removeObjectForKey:fileName];
    }
}


@end
