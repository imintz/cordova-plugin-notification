/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import <Cordova/CDV.h>
#import "CDVNotification.h"
#import "APPLocalNotification.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import "UILocalNotification+APPLocalNotification.h"
#import "UIApplication+APPLocalNotification.h"

@implementation CDVNotification

@synthesize serviceWorker;
@synthesize localNotification;

- (void) setup:(CDVInvokedUrlCommand*)command
{
    self.serviceWorker = [(CDVViewController*)self.viewController getCommandInstance:@"ServiceWorker"];
    self.localNotification = [(CDVViewController*)self.viewController getCommandInstance:@"LocalNotification"];
    
    // A messy way to create a stub object for porting the existing plugin to the service worker context
    //[serviceWorker.context evaluateScript:@"var cordova = {}; cordova.plugins = {}; cordova.plugins.notification = {}; cordova.plugins.notification.local = {};"];

    [self hasPermission];
    [self schedule];
    [self update];
    [self clear];
    [self clearAll];
    [self registerPermission];
    [self cancel];
    [self cancelAll];
    
    [serviceWorker.context evaluateScript:@"CDVNotification_setupListeners();"];

        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)hasPermission
{
    serviceWorker.context[@"cordova"][@"plugins"][@"notification"][@"local"][@"hasPermission"]= ^(JSValue *callback) {
        [self checkPermission:callback];
    };
}

- (void)schedule
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"CDVNotification_schedule"]= ^(JSValue *options, JSValue *callback) {
        /*CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        [command setValue:callback.toString forKey:@"callbackId"];
        [command setValue:options.toArray forKey:@"arguments"];
        [weakSelf.localNotification performSelectorOnMainThread:@selector(schedule:) withObject:command waitUntilDone:NO];*/
        NSArray* notifications = options.toArray;
        
        [weakSelf.commandDelegate runInBackground:^{
            for (NSDictionary* options in notifications) {
                UILocalNotification* notification;
                
                notification = [[UILocalNotification alloc]
                                initWithOptions:options];
                
                [weakSelf cancelForerunnerLocalNotification:notification];
                [[UIApplication sharedApplication] scheduleLocalNotification:notification];
                //[weakSelf fireEvent:@"schedule" notification:notification];
                
                if (notifications.count > 1) {
                    [NSThread sleepForTimeInterval:0.01];
                }
            }
        }];
    };
}

- (void)update
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"CDVNotification_update"]= ^(JSValue *options, JSValue *callback) {
        /*CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        [command setValue:callback.toString forKey:@"callbackId"];
        [command setValue:options.toArray forKey:@"arguments"];
        [weakSelf.localNotification performSelectorOnMainThread:@selector(update:) withObject:command waitUntilDone:NO];*/
        NSArray* notifications = options.toArray;
        
        [weakSelf.commandDelegate runInBackground:^{
            for (NSDictionary* options in notifications) {
                NSString* id = [options objectForKey:@"id"];
                UILocalNotification* notification;
                
                notification = [[UIApplication sharedApplication] localNotificationWithId:id];
                
                if (!notification)
                    continue;
                
                [weakSelf updateLocalNotification:[notification copy]
                                  withOptions:options];
                [weakSelf fireEvent:@"update" notification:notification];
                
                if (notifications.count > 1) {
                    [NSThread sleepForTimeInterval:0.01];
                }
            }
        }];
    };
}

- (void)clear
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"CDVNotification_clear"]= ^(JSValue *ids, JSValue *callback) {
        /*CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        [command setValue:callback.toString forKey:@"callbackId"];
        [command setValue:ids.toArray forKey:@"arguments"];
        [weakSelf.localNotification performSelectorOnMainThread:@selector(clear:) withObject:command waitUntilDone:NO];*/
        [weakSelf.commandDelegate runInBackground:^{
            for (NSString* id in ids.toArray) {
                UILocalNotification* notification;
                
                notification = [[UIApplication sharedApplication] localNotificationWithId:id];
                
                if (!notification)
                    continue;
                
                [[UIApplication sharedApplication] clearLocalNotification:notification];
                [weakSelf fireEvent:@"clear" notification:notification];
            }
        }];
    };
}

- (void)clearAll
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"cordova"][@"plugins"][@"notification"][@"local"][@"clearAll"]= ^(JSValue *callback) {
        CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        NSString *toCall = [NSString stringWithFormat:@"(%@)", callback.toString];
        [command setValue:toCall forKey:@"callbackId"];
        NSLog(@"Callback: %@", [command callbackId]);
        [weakSelf.localNotification performSelectorOnMainThread:@selector(clearAll:) withObject:command waitUntilDone:NO];
    };
}

- (void)cancel
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"CDVNotification_cancel"]= ^(JSValue *ids, JSValue *callback) {
        /*CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        [command setValue:callback.toString forKey:@"callbackId"];
        [command setValue:ids.toArray forKey:@"arguments"];
        [weakSelf.localNotification performSelectorOnMainThread:@selector(cancel:) withObject:command waitUntilDone:NO];*/
        [weakSelf.commandDelegate runInBackground:^{
            for (NSString* id in ids.toArray) {
                UILocalNotification* notification;
                
                notification = [[UIApplication sharedApplication] localNotificationWithId:id];
                
                if (!notification)
                    continue;
                
                [[UIApplication sharedApplication] cancelLocalNotification:notification];
                [weakSelf fireEvent:@"cancel" notification:notification];
            }
        }];
    };
}

- (void)cancelAll
{
    __weak CDVNotification *weakSelf = self;
    serviceWorker.context[@"cordova"][@"plugins"][@"notification"][@"local"][@"cancelAll"]= ^(JSValue *callback) {
        CDVInvokedUrlCommand *command = [[CDVInvokedUrlCommand alloc] init];
        [command setValue:callback.toString forKey:@"callbackId"];
        [weakSelf.localNotification performSelectorOnMainThread:@selector(cancelAll:) withObject:command waitUntilDone:NO];
    };
}

- (void)registerPermission
{
    serviceWorker.context[@"cordova"][@"plugins"][@"notification"][@"local"][@"registerPermission"]= ^(JSValue *callback) {
        if([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)])
        {
            if ([[UIApplication sharedApplication]
                 respondsToSelector:@selector(registerUserNotificationSettings:)])
            {
                UIUserNotificationType types;
                UIUserNotificationSettings *settings;
                types = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
                settings = [UIUserNotificationSettings settingsForTypes:types
                                                             categories:nil];
                [[UIApplication sharedApplication]
                 registerUserNotificationSettings:settings];
            }
        } else {
            [self checkPermission:callback];
        }
    };
}

- (void)application:(UIApplication*)application didReceiveLocalNotification:(UILocalNotification *)notification {
 /*   if ([notification wasUpdated])
        return;
    
    NSTimeInterval timeInterval = [notification timeIntervalSinceLastTrigger];
    
    NSString* event = (timeInterval <= 1 && deviceready) ? @"trigger" : @"click";
    
    [self fireEvent:event notification:notification];
    
    if (![event isEqualToString:@"click"])
        return;
    
    if ([notification isRepeating]) {
        [self fireEvent:@"clear" notification:notification];
    } else {
        [self.app cancelLocalNotification:notification];
        [self fireEvent:@"cancel" notification:notification];
    }*/
}

- (void)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    UILocalNotification *notification = [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (notification) {
        //DO think on launching from click
    }
}

- (void)checkPermission:(JSValue*)callback
{
        NSString *hasPermission = @"false";
        if ([[UIApplication sharedApplication]
             respondsToSelector:@selector(registerUserNotificationSettings:)])
        {
            UIUserNotificationType types;
            UIUserNotificationSettings *settings;
            settings = [[UIApplication sharedApplication]
                        currentUserNotificationSettings];
            types = UIUserNotificationTypeAlert|UIUserNotificationTypeBadge|UIUserNotificationTypeSound;
            if (settings.types & types) {
                hasPermission = @"true";
            }
        } else {
            hasPermission = @"true";
        }
        NSString *toDispatch = [NSString stringWithFormat:@"(%@)(%@);", callback, hasPermission];
        [serviceWorker.context evaluateScript:toDispatch];
}

- (void) cancelForerunnerLocalNotification:(UILocalNotification*)notification
{
    NSString* id = notification.options.id;
    UILocalNotification* forerunner;
    
    forerunner = [[UIApplication sharedApplication] localNotificationWithId:id];
    
    if (!forerunner)
        return;
    
    [[UIApplication sharedApplication] cancelLocalNotification:forerunner];
}

- (void) updateLocalNotification:(UILocalNotification*)notification
                     withOptions:(NSDictionary*)newOptions
{
    NSMutableDictionary* options = [notification.userInfo mutableCopy];
    
    [options addEntriesFromDictionary:newOptions];
    [options setObject:[NSDate date] forKey:@"updatedAt"];
    
    notification = [[UILocalNotification alloc]
                    initWithOptions:options];
    
    [self cancelForerunnerLocalNotification:notification];
    [[UIApplication sharedApplication] scheduleLocalNotification:notification];
}

- (void) fireEvent:(NSString*)event notification:(UILocalNotification*)notification
{
    NSString* params = [NSString stringWithFormat:
                        @"\"%@\"", [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive ? @"foreground" : @"background"];
    
    if (notification) {
        NSString* args = [notification encodeToJSON];
        
        params = [NSString stringWithFormat:
                  @"%@,'%@'",
                  args, [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive ? @"foreground" : @"background"];
    }
    
    NSString *toDispatch = [NSString stringWithFormat:@"CDVNotification_fireEvent('%@',%@);", event, params];
    [serviceWorker.context evaluateScript:toDispatch];
}
@end