//
//  iSXMAnalysisModule.m
//  iOScanX Module
//
//  Created by Alessio Maffeis on 17/06/13.
//  Copyright (c) 2013 Alessio Maffeis. All rights reserved.
//

#import "iSXMDataProtection.h"
#import "NSFileManager+DirectoryLocations.h"


@implementation iSXMDataProtection {
    
    NSString *_bundleIdentifier;
    NSString *_tmpPath;
    NSBundle *_bundle;
}

@synthesize delegate = _delegate;
@synthesize name = _name;
@synthesize prefix = _prefix;
@synthesize metrics = _metrics;

- (id) init {
    
    self = [super init];
    if (self) {
        _bundle = [NSBundle bundleForClass:[iSXMDataProtection class]];
        NSString *plist = [_bundle pathForResource:@"Module" ofType:@"plist"];
        NSDictionary *moduleInfo = [NSDictionary dictionaryWithContentsOfFile:plist];
        _name = [[NSString alloc] initWithString:[moduleInfo objectForKey:@"name"]];
        _prefix = [[NSString alloc] initWithString:[moduleInfo objectForKey:@"prefix"]];
        _readonly = [[moduleInfo objectForKey:@"readonly"] boolValue];

        NSMutableArray *metrics = [NSMutableArray array];
        for(NSDictionary *metric in [moduleInfo objectForKey:@"metrics"]) {
            SXMetric *sxm = [[SXMetric alloc] initWithName:[metric objectForKey:@"name"] andInfo:[metric objectForKey:@"description"]];
            [metrics addObject:sxm];
            [sxm release];
        }
        _metrics = [[NSArray alloc] initWithArray:metrics];
        _bundleIdentifier = [[_bundle bundleIdentifier] retain];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *modulesPath = [fm applicationSupportSubDirectory:@"Modules"];
        _tmpPath = [[NSString stringWithFormat:@"%@/%@/tmp", modulesPath, _bundleIdentifier] retain];
        [fm createDirectoryAtPath:_tmpPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return self;
}


- (void) analyze:(id)item {
    
    NSString *theId = [item objectAtIndex:0];
    iSXApp *theItem = [item objectAtIndex:1];
    
    NSMutableDictionary *results = [[[NSMutableDictionary alloc] init] autorelease];
    for(SXMetric *metric in _metrics)
        [results setObject:[NSNull null] forKey:[NSString stringWithFormat:@"%@_%@", _prefix, metric.name]];

    if ([self itemIsValid:theItem])
    {
        NSString *itemPath = [self temporaryItem:theItem];
        if(itemPath != nil)
        {
            NSInteger calendar = 0;
            NSInteger micro = 0;
            NSInteger media = 0;
            NSInteger contacts = 0;
            NSInteger location = 0;
            NSInteger social = 0;
            NSInteger network = 0;
            
            NSString *escAppName = [theItem.bundleName stringByReplacingOccurrencesOfString:@"'"
                                                                           withString:@"'\\''"];
            NSString *escExeName = [theItem.executableName stringByReplacingOccurrencesOfString:@"'"
                                                                           withString:@"'\\''"];
            NSString *decrypted = [NSString stringWithFormat:@"%@/%@/%@.decrypted", itemPath, escAppName, escExeName];
            NSArray *args = [NSArray arrayWithObjects: decrypted, nil];
            NSTask *dump = [[NSTask alloc] init];
            NSPipe *output = [NSPipe pipe];
            [dump setStandardOutput:output];
            [dump setLaunchPath:@"/usr/bin/strings"];
            [dump setArguments:args];
            [dump launch];
            
            NSData *dataRead = [[output fileHandleForReading] readDataToEndOfFile];
            NSString *read = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
            
            if(read != nil)
            {
                // Calendar:
                if ([read rangeOfString:@"EKEvent"].location != NSNotFound)
                    calendar = 1;
                
                // Microphone:
                if ([read rangeOfString:@"requestRecordPermission"].location != NSNotFound)
                {
                    micro = 1;
                }
                    
                // Media:
                if ([read rangeOfString:@"UIImagePickerController"].location != NSNotFound)
                {
                    media = 1;
                }
                else
                {
                    if ([read rangeOfString:@"AVCapture"].location != NSNotFound)
                        media = 1;
                }
                
                // Contacts:
                if ([read rangeOfString:@"ABPeople"].location != NSNotFound)
                {
                    contacts = 1;
                }
                else
                {
                    if ([read rangeOfString:@"ABAddressBook"].location != NSNotFound)
                        contacts = 1;
                }
                // Location:
                if ([read rangeOfString:@"CLLocationManager"].location != NSNotFound)
                    location = 1;
                
                // Social:
                if ([read rangeOfString:@"ACAccountStore"].location != NSNotFound)
                    social = 1;
                
                // Network:
                if ([read rangeOfString:@"NSURLRequest"].location != NSNotFound){
                    network = 1;
                }
                else
                {
                    if ([read rangeOfString:@"NSURLConnection"].location != NSNotFound)
                    {
                        network = 1;
                    }
                    else
                    {
                        if ([read rangeOfString:@"CFSocket"].location != NSNotFound)
                        {
                            network = 1;
                        }
                        else
                        {
                            if ([read rangeOfString:@"CFStream"].location != NSNotFound)
                                network = 1;
                        }
                    }
                }
                
                [read release];
            }
            
            [dump waitUntilExit];
            [dump release];
            
            [results setObject:[NSNumber numberWithInteger:calendar]
                        forKey: [NSString stringWithFormat:@"%@_calendar", _prefix]];
            [results setObject:[NSNumber numberWithInteger:micro]
                        forKey: [NSString stringWithFormat:@"%@_micro", _prefix]];
            [results setObject:[NSNumber numberWithInteger:media]
                        forKey: [NSString stringWithFormat:@"%@_media", _prefix]];
            [results setObject:[NSNumber numberWithInteger:contacts]
                        forKey: [NSString stringWithFormat:@"%@_contacts", _prefix]];
            [results setObject:[NSNumber numberWithInteger:location]
                        forKey: [NSString stringWithFormat:@"%@_location", _prefix]];
            [results setObject:[NSNumber numberWithInteger:social]
                        forKey: [NSString stringWithFormat:@"%@_social", _prefix]];
            [results setObject:[NSNumber numberWithInteger:network]
                        forKey: [NSString stringWithFormat:@"%@_network", _prefix]];
        }
    }
    
    [_delegate storeMetrics:results forItem:theId];
}

- (BOOL) itemIsValid:(iSXApp*)item {
    
    if (item.path == nil)
        return NO;
    if (item.ID == nil)
        return NO;
    
    return YES;
}

- (NSString*) temporaryItem:(iSXApp*)item {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (_readonly)
    {
        @synchronized(self)
        {
            if (![fm fileExistsAtPath:[item.path stringByDeletingPathExtension]])
            {
                NSString *dir = [NSString stringWithFormat:@"--directory=%@", [item.path stringByDeletingLastPathComponent]];
                NSArray *args = [NSArray arrayWithObjects: @"-xf", item.path, dir, nil];
                NSTask *untar = [[NSTask alloc] init];
                [untar setLaunchPath:@"/usr/bin/tar"];
                [untar setArguments:args];
                [untar launch];
                [untar waitUntilExit];
                int exitCode = [untar terminationStatus];
                [untar release];
                
                if (exitCode != 0)
                    return nil;
            }
        }
        
        return [item.path stringByDeletingLastPathComponent];
    }
    else
    {
        NSString *tmpItemPath = [_tmpPath stringByAppendingPathComponent:item.ID];
        [fm createDirectoryAtPath:tmpItemPath withIntermediateDirectories:YES attributes:nil error:nil];

        NSString *dir = [NSString stringWithFormat:@"--directory=%@", tmpItemPath];
        NSArray *args = [NSArray arrayWithObjects: @"-xf", item.path, dir, nil];
        
        NSTask *untar = [[NSTask alloc] init];
        [untar setLaunchPath:@"/usr/bin/tar"];
        [untar setArguments:args];
        [untar launch];
        [untar waitUntilExit];
        int exitCode = [untar terminationStatus];
        [untar release];
        
        return  exitCode == 0 ? [tmpItemPath stringByAppendingPathComponent:item.name] : nil;
    }
}

- (BOOL) deleteItem:(iSXApp*)item {
    
    if (_readonly)
        return YES;
    
    return [[NSFileManager defaultManager] removeItemAtPath:[_tmpPath stringByAppendingPathComponent:item.ID] error:nil];
}

- (void) dealloc {
    
    [_name release];
    [_prefix release];
    [_metrics release];
    [_bundleIdentifier release];
    [_tmpPath release];
    [super dealloc];
}

@end
