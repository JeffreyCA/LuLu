//
//  file: DaemonComms.m
//  project: lulu (shared)
//  description: talk to daemon
//
//  created by Patrick Wardle
//  copyright (c) 2017 Objective-See. All rights reserved.
//

#import "consts.h"
#import "logging.h"
#import "DaemonComms.h"

@implementation DaemonComms

@synthesize daemon;
@synthesize xpcServiceConnection;

//init
// ->create XPC connection & set remote obj interface
-(id)init
{
    //super
    self = [super init];
    if(nil != self)
    {
        //alloc/init
        xpcServiceConnection = [[NSXPCConnection alloc] initWithMachServiceName:DAEMON_MACH_SERVICE options:0];
        
        //set remote object interface
        self.xpcServiceConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(UserProtocol)];
        
        //resume
        [self.xpcServiceConnection resume];
    }
    
    return self;
}

//checkin with daemon client status
-(void)clientCheckin
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to check in with daemon");
    
    //set status
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'clientCheckin' method on launch daemon (error: %@)", proxyError]);
          
    }] clientCheckin];
    
    return;
}

//get preferences
// note: synchronous, will block until daemon responds
-(NSDictionary*)getPreferences
{
    //preferences
    __block NSDictionary* preferences = nil;
    
    //wait sema
    dispatch_semaphore_t semaphore = NULL;
    
    //init sema
    semaphore = dispatch_semaphore_create(0);
    
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for preferences");
    
    //request preferences
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
      {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getPreferences' method on launch daemon (error: %@)", proxyError]);
          
          //signal sema
          dispatch_semaphore_signal(semaphore);
          
      }] getPreferences:^(NSDictionary* preferencesFromDaemon)
     {
         //dbg msg
         logMsg(LOG_DEBUG, [NSString stringWithFormat:@"got preferences: %@", preferencesFromDaemon]);
         
         //save
         preferences = preferencesFromDaemon;
         
         //signal sema
         dispatch_semaphore_signal(semaphore);
         
     }];
    
    //XPC is async
    // wait for preferences from daemon
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return preferences;
}

//update (save) preferences
-(void)updatePreferences:(NSDictionary*)preferences
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to update preferences");
    
    //update prefs
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'updatePreferences' method on launch daemon (error: %@)", proxyError]);
          
    }] updatePreferences:preferences];
    
    return;
}

//get rules
// ->optionally waits (blocks) for change
-(void)getRules:(BOOL)wait4Change reply:(void (^)(NSDictionary*))reply;
{
    //dbg msg
    logMsg(LOG_DEBUG, [NSString stringWithFormat:@"sending request, via XPC, to get rules (wait: %d)", wait4Change]);
    
    //make XPC request to get rules
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'getRules' method on launch daemon (error: %@)", proxyError]);
        
    }] getRules:wait4Change reply:^(NSDictionary* rules)
    {
         //respond
         reply(rules);
    }];
    
    return;
}

//add rule
-(void)addRule:(NSString*)processPath action:(NSUInteger)action
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to add rule");
    
    //make XPC request to add rule
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'addRule' method on launch daemon (error: %@)", proxyError]);
        
    }] addRule:processPath action:action user:getuid()];
    
    return;
}

//update rule
// for now, just action (block/allow)
-(void)updateRule:(NSString*)processPath action:(NSUInteger)action
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to update rule");
    
    //make XPC request to add rule
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'updateRule' method on launch daemon (error: %@)", proxyError]);
          
    }] updateRule:processPath action:action user:getuid()];
    
    return;
}

//delete rule
-(void)deleteRule:(NSString*)processPath
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to delete rule");
    
    //delete rule
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'deleteRule' method on launch daemon (error: %@)", proxyError]);
        
    }] deleteRule:processPath];
    
    return;
}

//import rules
-(BOOL)importRules:(NSString*)rulesFile
{
    //flag
    __block BOOL importedRules = NO;
    
    //init wait sema
    __block dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, to import rules");
    
    //import rules
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'importRules' method on launch daemon (error: %@)", proxyError]);
        
    }] importRules:rulesFile reply:^(BOOL result)
    {
        //set flag
        importedRules = YES;
        
        //signal response was received
        dispatch_semaphore_signal(semaphore);
    }];
    
    //wait for response to be received
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    return importedRules;
}

//ask (and then block) for an alert
-(void)alertRequest:(void (^)(NSDictionary* alert))reply
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for alert");
    
    //request alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
        //err msg
        logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertRequest' method on launch daemon (error: %@)", proxyError]);
        
    }] alertRequest:^(NSDictionary* alert)
    {
        //respond
        reply(alert);
    }];
    
    return;
}

//send alert response back to the user
-(void)alertResponse:(NSDictionary *)alert
{
    //dbg msg
    logMsg(LOG_DEBUG, @"sending request, via XPC, for alert response");
    
    //respond to alert
    [[self.xpcServiceConnection remoteObjectProxyWithErrorHandler:^(NSError * proxyError)
    {
          //err msg
          logMsg(LOG_ERR, [NSString stringWithFormat:@"failed to execute 'alertResponse' method on launch daemon (error: %@)", proxyError]);
          
    }] alertResponse:alert];
    
    return;
}

@end
