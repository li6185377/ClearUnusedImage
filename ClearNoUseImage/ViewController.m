//
//  ViewController.m
//  ClearNoUseImage
//
//  Created by ljh on 15/3/23.
//  Copyright (c) 2015年 SY. All rights reserved.
//

#import "ViewController.h"

@interface ViewController()
{
    NSDictionary* objects;
    NSString* projectDirPath;
}
@property(strong,nonatomic)NSMutableDictionary* unusedImageNames;
@property(strong,nonatomic)NSMutableDictionary* imageNames;
@property(strong,nonatomic)NSMutableArray* fileNames;

@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"搜索代码中未使用的图片";
    
    self.imageNames = [NSMutableDictionary dictionary];
    self.fileNames = [NSMutableArray array];
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

        
        NSArray* targets = mainInfo[@"targets"];
        [self extractBuildPhasesContentWith:targets];
        self.unusedImageNames = [NSMutableDictionary dictionaryWithDictionary:_imageNames];
        
        NSString* mainGroupKey = mainInfo[@"mainGroup"];
        
        NSDictionary* mainGroupDic = objects[mainGroupKey];

        projectDirPath = [path stringByDeletingLastPathComponent];
        [self checkImageUsedWithDir:projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resultTextView.string = @"开始遍历修改xcodeproj文件。。。会比较慢";
        });
        
        
        NSArray* imageNames = [self.unusedImageNames.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString* obj1, NSString* obj2) {
            return [obj1 compare:obj2];
        }];
        
        NSString* projectContent = [NSString stringWithContentsOfFile:projectPath encoding:NSUTF8StringEncoding error:nil];
        NSMutableArray* projectContentArray = [NSMutableArray arrayWithArray:[projectContent componentsSeparatedByString:@"\n"]];
        
        NSArray* deleteImages = _unusedImageNames.allValues;
        
        for (NSDictionary* imageInfo in deleteImages) {
            
            NSArray* imageKeys = imageInfo[@"keys"];
            for (NSString* key in imageKeys) {
                [projectContentArray enumerateObjectsUsingBlock:^(NSString* obj, NSUInteger idx, BOOL *stop) {
                    if([obj containsString:key])
                    {
                        [projectContentArray removeObjectAtIndex:idx];
                    }
                }];
            }
            
            NSArray* imagePaths = imageInfo[@"paths"];
            for (NSString* path in imagePaths) {
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
                self.resultTextView.string = @"你的图片代码里面都有用到";
            }
        });
    });
}
-(void)checkImageUsedWithDir:(NSString*)dir PBXGroup:(NSDictionary*)PBXGroup key:(NSString*)fromKey
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
        if([pathExtension isEqualToString:@"m"])
        {
            [self checkImageWithCodePath:dir isXib:NO];
        }
        else if([pathExtension isEqualToString:@"xib"])
        {
            [self checkImageWithCodePath:dir isXib:YES];
        }
        else if([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"])
        {
            [self saveImagePathInfo:dir key:fromKey];
        }
    }
    else
    {
        for (NSString* key in children) {
            NSDictionary* childrenDic = objects[key];
            [self checkImageUsedWithDir:dir PBXGroup:childrenDic key:key];
        }
    }
}
-(void)extractBuildPhasesContentWith:(NSArray*)targets
{
    for (NSString* target in targets)
    {
        NSDictionary* targetInfo = objects[target];
        NSArray* buildPhases = targetInfo[@"buildPhases"];
        for (NSString* buildPhaseKey in buildPhases) {
            NSDictionary* phaseInfo = objects[buildPhaseKey];
            NSString* type = phaseInfo[@"isa"];

            if([type isEqualToString:@"PBXSourcesBuildPhase"] || [type isEqualToString:@"PBXResourcesBuildPhase"])
            {
                NSArray* files = phaseInfo[@"files"];
                for (NSString* fileKey in files) {
                    NSDictionary* fileInfo = objects[fileKey];
                    NSString* fileRef = fileInfo[@"fileRef"];
                    NSDictionary* fileRefDic = objects[fileRef];
                    NSString* fileName = fileRefDic[@"name"]?:fileRefDic[@"path"];
      
                    NSString* pathExtension = [fileName.pathExtension lowercaseString];
                    if([pathExtension isEqualToString:@"m"] || [pathExtension isEqualToString:@"xib"])
                    {
                        [_fileNames addObject:fileName];
                    }
                    else if([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"])
                    {
                        fileName = fileName.stringByDeletingPathExtension;
                        NSInteger location = [fileName rangeOfString:@"@"].location;
                        if(location != NSNotFound)
                        {
                            fileName = [fileName substringToIndex:location];
                        }
                        fileName = [fileName stringByAppendingPathExtension:pathExtension];
                        
                        NSMutableDictionary* imageInfo = [_imageNames objectForKey:fileName];
                        if(imageInfo == nil)
                        {
                            imageInfo = [NSMutableDictionary dictionary];
                            [_imageNames setObject:imageInfo forKey:fileName];
                        }
                        NSMutableArray* imageKeys = imageInfo[@"keys"];
                        if(imageKeys == nil)
                        {
                            imageKeys = [NSMutableArray array];
                            [imageInfo setObject:imageKeys forKey:@"keys"];
                        }
                        if([imageKeys containsObject:fileKey] == NO)
                        {
                            [imageKeys addObject:fileKey];
                        }
                    }
                }
            }
            
        }
    }
}
-(void)saveImagePathInfo:(NSString*)imagePath key:(NSString*)key
{
    NSString* fileName = imagePath.lastPathComponent;
    NSString* pathExtension = fileName.pathExtension;
    
    fileName = fileName.stringByDeletingPathExtension;
    NSInteger location = [fileName rangeOfString:@"@"].location;
    if(location != NSNotFound)
    {
        fileName = [fileName substringToIndex:location];
    }
    fileName = [fileName stringByAppendingPathExtension:pathExtension];
    
    NSMutableDictionary* imageInfo = [_imageNames objectForKey:fileName];
    if(imageInfo)
    {
        NSMutableArray* imagePaths = imageInfo[@"paths"];
        if(imagePaths == nil)
        {
            imagePaths = [NSMutableArray array];
            [imageInfo setObject:imagePaths forKey:@"paths"];
        }
        if([imagePaths containsObject:imagePath] == NO)
        {
            [imagePaths addObject:imagePath];
        }
        
        NSMutableArray* imageKeys = imageInfo[@"keys"];
        if(imageKeys == nil)
        {
            imageKeys = [NSMutableArray array];
            [imageInfo setObject:imageKeys forKey:@"keys"];
        }
        if([imageKeys containsObject:key] == NO)
        {
            [imageKeys addObject:key];
        }
    }
}
-(void)checkImageWithCodePath:(NSString*)mPath isXib:(BOOL)isXib
{
    NSString* contentFile = [NSString stringWithContentsOfFile:mPath encoding:NSUTF8StringEncoding error:nil];
    
    NSString *regularStr = @"\"(\\\\\"|[^\"^\\s]|[\\r\\n])+\"";
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:0 error:nil];
    NSArray* matches = [regex matchesInString:contentFile options:0 range:NSMakeRange(0, contentFile.length)];
    
    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = [match range];
        range.location += 1;
        range.length -=2;
        NSString* subStr = [contentFile substringWithRange:range];
        
        NSString* pathExtension = [subStr.pathExtension lowercaseString];
        if(isXib && pathExtension.length == 0)
        {
            continue;
        }
        if(pathExtension.length == 0)
        {
            pathExtension = @"png";
        }
        else if([pathExtension isEqualToString:@"png"] || [pathExtension isEqualToString:@"gif"] || [pathExtension isEqualToString:@"jpg"] || [pathExtension isEqualToString:@"jpeg"])
        {
            
        }
        else
        {
            ///不符合图片的后缀名
            continue;
        }
        
        NSString* fileName = subStr.stringByDeletingPathExtension;
        NSInteger location = [fileName rangeOfString:@"@"].location;
        if(location != NSNotFound)
        {
            fileName = [fileName substringToIndex:location];
        }
        fileName = [fileName stringByAppendingPathExtension:pathExtension];
        
        if(fileName.length == 0)
        {
            continue;
        }
        
        [_unusedImageNames removeObjectForKey:fileName];
    }
}

@end
