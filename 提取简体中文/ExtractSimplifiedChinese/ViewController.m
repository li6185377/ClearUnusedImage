//
//  ViewController.m
//  ExtractSimplifiedChinese
//
//  Created by ljh on 15/3/27.
//  Copyright (c) 2015年 SY. All rights reserved.
//

#import "ViewController.h"

@interface ViewController()
@property (weak) IBOutlet NSTextField *textField;

@property (unsafe_unretained) IBOutlet NSTextView *resultTextView;

@end

@implementation ViewController
{
    NSDictionary* objects;
    NSString* projectDirPath;
    
    
    NSMutableArray* existStringKey;
    NSMutableArray* unusedStringKey;
    
    NSMutableArray* unextractString;
    NSMutableArray* unextractJSONString;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    existStringKey = [NSMutableArray array];
    unextractString = [NSMutableArray array];
    unextractJSONString = [NSMutableArray array];
}
- (IBAction)showView2:(id)sender {
    
   NSWindowController* windowVC = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"window2"];
    NSWindow* myWindow = [windowVC window];
    [NSApp runModalForWindow:myWindow];
}

- (IBAction)showView3:(id)sender {
    
    NSWindowController* windowVC = [[NSStoryboard storyboardWithName:@"Main" bundle:nil] instantiateControllerWithIdentifier:@"window3"];
    NSWindow* myWindow = [windowVC window];
    [NSApp runModalForWindow:myWindow];
}

-(void)viewDidAppear
{
    [super viewDidAppear];
    [NSApp runModalForWindow:self.view.window];
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
        NSString* extractFilePath = [projectDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_提取的中文.txt",path.lastPathComponent.stringByDeletingPathExtension]];
        NSString* unusedKeyFilePath = [projectDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_未使用到key.txt",path.lastPathComponent.stringByDeletingPathExtension]];
        
        [self extractStringsWithDir:projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
        unusedStringKey = [existStringKey mutableCopy];
        
        [self checkStringWithDir:projectDirPath PBXGroup:mainGroupDic key:mainGroupKey];
        
        [unextractString addObjectsFromArray:unextractJSONString];
        
        [[unextractString componentsJoinedByString:@"\n"] writeToFile:extractFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [[unusedStringKey componentsJoinedByString:@"\n"] writeToFile:unusedKeyFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.resultTextView.string = [self.resultTextView.string stringByAppendingFormat:@"\n遍历完成\n"];
        });
    });
}
-(void)extractStringsWithDir:(NSString*)dir PBXGroup:(NSDictionary*)PBXGroup key:(NSString*)fromKey
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
        if([pathExtension isEqualToString:@"strings"])
        {
            [self extractStringsWithPath:dir];
        }
    }
    else
    {
        for (NSString* key in children) {
            NSDictionary* childrenDic = objects[key];
            [self extractStringsWithDir:dir PBXGroup:childrenDic key:key];
        }
    }
}
-(void)extractStringsWithPath:(NSString*)path
{
    NSString* contentString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    if(contentString.length == 0)
        return;
    
    NSArray* array = [contentString componentsSeparatedByString:@"\n"];
    for (NSString* line in array) {
        
        NSArray* component = [line componentsSeparatedByString:@"\" = \""];
        if(component.count == 2)
        {
            NSString* key = [component[0] substringFromIndex:1];
            [existStringKey addObject:key];
        }
    }
}

-(void)checkStringWithDir:(NSString*)dir PBXGroup:(NSDictionary*)PBXGroup key:(NSString*)fromKey
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
            [self checkStringWithCodePath:dir];
        }
        if([pathExtension isEqualToString:@"json"])
        {
            [self checkStringWithJSONPath:dir];
        }
    }
    else
    {
        for (NSString* key in children) {
            NSDictionary* childrenDic = objects[key];
            [self checkStringWithDir:dir PBXGroup:childrenDic key:key];
        }
    }
    
}
-(void)checkStringWithJSONPath:(NSString*)mPath
{
    NSString* mFileName = mPath.lastPathComponent.stringByDeletingPathExtension;
    ///过滤一些文件
    if([mFileName containsString:@"MobClick"])
        return;
    
    NSMutableString* contentFile = [NSMutableString stringWithContentsOfFile:mPath encoding:NSUTF8StringEncoding error:nil];
    if(contentFile.length == 0)
        return;
    
    NSString *regularStr = @"\"(\\\\\"|[^\"]|[\\r\\n])+\"";
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:0 error:nil];
    NSArray* matches = [regex matchesInString:contentFile options:0 range:NSMakeRange(0, contentFile.length)];
    
    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = [match range];
        
        NSString* subStr = [contentFile substringWithRange:range];
        
        BOOL zhongwen = NO;
        ///从@" 后面开始算 是否有中文
        for(int i=1; i< subStr.length;i++)
        {
            int a = [subStr characterAtIndex:i];
            if( a > 0x4e00 && a < 0x9fff)
            {
                zhongwen = YES;
                break;
            }
            const char    *cString = [[subStr substringWithRange:NSMakeRange(i, 1)] UTF8String];
            if (strlen(cString) == 3)
            {
                zhongwen = YES;
                break;
            }
        }
        if(zhongwen == NO)
        {
            continue;
        }
        
        subStr = [subStr substringWithRange:NSMakeRange(1, subStr.length - 2)];
        if([existStringKey containsObject:subStr] == NO)
        {
            if([unextractJSONString containsObject:subStr] == NO)
            {
                [unextractJSONString addObject:subStr];
            }
        }
        else
        {
            [unusedStringKey removeObject:subStr];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        self.resultTextView.string = [self.resultTextView.string stringByAppendingFormat:@"\n%@ ok",mFileName];
    });
}

-(void)checkStringWithCodePath:(NSString*)mPath
{
    NSString* mFileName = mPath.lastPathComponent.stringByDeletingPathExtension;
    ///过滤一些文件
    if([mFileName containsString:@"MobClick"])
        return;
    
    NSMutableString* contentFile = [NSMutableString stringWithContentsOfFile:mPath encoding:NSUTF8StringEncoding error:nil];
    if(contentFile.length == 0)
        return;
    
    NSString *regularStr = @"@\"(\\\\\"|[^\"]|[\\r\\n])+\"";
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:regularStr options:0 error:nil];
    NSArray* matches = [regex matchesInString:contentFile options:0 range:NSMakeRange(0, contentFile.length)];
    
    int offset = 0;
    BOOL hasChanged = NO;
    for (NSTextCheckingResult *match in matches)
    {
        NSRange range = [match range];
        range.location += offset;
        
        int location = (int)range.location - 8;
        if(location >= 0)
        {
            ///打印日志的不提取
            NSString* logPrefix = [contentFile substringWithRange:NSMakeRange(location, 8)];
            if([logPrefix hasSuffix:@"Log("] || [logPrefix isEqualToString:@" forKey:"])
            {
                continue;
            }
        }
        
        NSString* subStr = [contentFile substringWithRange:range];

        BOOL zhongwen = NO;
        ///从@" 后面开始算 是否有中文
        for(int i=2; i< subStr.length;i++)
        {    
            int a = [subStr characterAtIndex:i];
            if( a > 0x4e00 && a < 0x9fff)
            {
                zhongwen = YES;
                break;
            }
            const char    *cString = [[subStr substringWithRange:NSMakeRange(i, 1)] UTF8String];
            if (strlen(cString) == 3)
            {
                zhongwen = YES;
                break;
            }
        }
        if(zhongwen == NO)
        {
            continue;
        }
        
        location = (int)range.location - 7;
        if(location >= 0)
        {
            NSString* checkStr = [contentFile substringWithRange:NSMakeRange(location, 7)];
            if([checkStr isEqualToString:@"SY_STR("])
            {
                subStr = [subStr substringWithRange:NSMakeRange(2, subStr.length - 3)];
                if([existStringKey containsObject:subStr] == NO)
                {
                    if([unextractString containsObject:subStr] == NO)
                    {
                        [unextractString addObject:subStr];
                    }
                }
                else
                {
                    [unusedStringKey removeObject:subStr];
                }
                continue;
            }
        }
        
        NSString* replaceStr = [NSString stringWithFormat:@"SY_STR(%@)",subStr];
        
        offset += replaceStr.length - subStr.length;
        
        [contentFile replaceCharactersInRange:range withString:replaceStr];
        
        subStr = [subStr substringWithRange:NSMakeRange(2, subStr.length - 3)];
        if([existStringKey containsObject:subStr] == NO)
        {
            if([unextractString containsObject:subStr] == NO)
            {
                [unextractString addObject:subStr];
            }
        }
        else
        {
            [unusedStringKey removeObject:subStr];
        }
        hasChanged = YES;
    }
    if(hasChanged)
    {
//        [contentFile writeToFile:mPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
       self.resultTextView.string = [self.resultTextView.string stringByAppendingFormat:@"\n%@ ok",mFileName];
    });
}


-(void)viewWillAppear
{
    [super viewWillAppear];
    self.view.window.delegate = (id)self;
}
-(void)windowWillClose:(NSNotification *)notification
{
    [NSApp terminate:nil];
}
@end

@interface ViewController2()
@property (weak) IBOutlet NSTextField *keyTextField;

@property (weak) IBOutlet NSTextField *valueTextField;
@end

@implementation ViewController2
- (IBAction)bt_action:(id)sender {
    
    NSString* keyPath = _keyTextField.stringValue;
    NSString* valuePath = _valueTextField.stringValue;

    NSString* writePath = [keyPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%@_合并.txt",    keyPath.lastPathComponent.stringByDeletingPathExtension,    valuePath.lastPathComponent.stringByDeletingPathExtension]];
    
    NSString* keyContent = [NSString stringWithContentsOfFile:keyPath encoding:NSUTF8StringEncoding error:nil];
    NSArray* keyArray = [keyContent componentsSeparatedByString:@"\n"];
    
    NSString* valueContent = [NSString stringWithContentsOfFile:valuePath encoding:NSUTF8StringEncoding error:nil];
    NSArray* valueArray = [valueContent componentsSeparatedByString:@"\n"];
    
    if(keyArray.count != valueArray.count)
    {
        NSAlert* alert = [NSAlert alertWithError:[NSError errorWithDomain:@"key 跟 value 的行数不对" code:-1 userInfo:nil]];
        [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        return;
    }
    
    NSMutableString* sb = [NSMutableString string];
    for (int i = 0; i< keyArray.count; i++)
    {
        NSString* jjj = [keyArray objectAtIndex:i];
        NSString* fff = [valueArray objectAtIndex:i];
        if([jjj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0)
        {
            continue;
        }
        [sb appendFormat:@"\"%@\" = \"%@\";\n",jjj,fff];
    }
    
    [sb writeToFile:writePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}


-(void)viewWillAppear
{
    [super viewWillAppear];
    self.view.window.delegate = (id)self;
}
-(void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModalWithCode:1];
}
@end


@interface ViewController3()
@property (weak) IBOutlet NSTextField *keyTextField;

@property (weak) IBOutlet NSTextField *valueTextField;
@end

@implementation ViewController3
- (IBAction)bt_action:(id)sender {
    
    NSString* keyPath = _keyTextField.stringValue;
    NSString* valuePath = _valueTextField.stringValue;
    
    
    NSString* keyContent = [NSString stringWithContentsOfFile:keyPath encoding:NSUTF8StringEncoding error:nil];
    NSArray* keyArray = [keyContent componentsSeparatedByString:@"\n"];
    
    NSString* valueContent = [NSString stringWithContentsOfFile:valuePath encoding:NSUTF8StringEncoding error:nil];
    NSArray* valueArray = [valueContent componentsSeparatedByString:@"\n"];
    
    NSMutableArray* changedKeyContent = [keyArray mutableCopy];
    for (int i = 0; i< keyArray.count; i++)
    {
        NSString* keyLine = [keyArray objectAtIndex:i];
        NSArray* component = [keyLine componentsSeparatedByString:@"\" = \""];
        if(component.count == 2)
        {
            NSString* key = [component[0] substringFromIndex:1];
            if([valueArray containsObject:key])
            {
                [changedKeyContent removeObject:keyLine];
            }
        }
        
    }
    
    [[changedKeyContent componentsJoinedByString:@"\n"] writeToFile:keyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

-(void)viewWillAppear
{
    [super viewWillAppear];
    self.view.window.delegate = (id)self;
}
-(void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModalWithCode:1];
}
@end