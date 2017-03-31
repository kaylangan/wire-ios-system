// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


#import "ZMSDispatchGroup.h"

@interface ZMSDispatchGroup ()

@property (nonatomic) NSMutableDictionary<NSString *, NSString *> *logs;
@property (nonatomic, copy) NSString* label;
@property (nonatomic) dispatch_group_t group;
@property (nonatomic) NSInteger count;
@property (nonatomic) dispatch_queue_t logQueue;

@end



@implementation ZMSDispatchGroup

+ (instancetype)groupWithDispatchGroup:(dispatch_group_t)group label:(NSString *)label;
{
    return [[ZMSDispatchGroup alloc] initWithGroup:group label:label];
}

- (instancetype)initWithGroup:(dispatch_group_t)group label:(NSString *)label;
{
    self = [super init];
    if(self) {
        self.label = label;
        self.group = group;
        self.logs = [[NSMutableDictionary alloc] init];
        self.logQueue = dispatch_queue_create("Dispatch group queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

+ (instancetype)groupWithLabel:(NSString *)label
{
    return [[ZMSDispatchGroup alloc] initWithGroup:dispatch_group_create() label:label];
}

- (long)waitWithTimeout:(dispatch_time_t)timeout
{
    return dispatch_group_wait(self.group, timeout);
}

- (long)waitForInterval:(NSTimeInterval)timeout;
{
    dispatch_time_t start = DISPATCH_TIME_NOW;
    int64_t delta = ((int64_t)(timeout) * 1000) * (int64_t)NSEC_PER_MSEC;
    return dispatch_group_wait(self.group, dispatch_time(start, delta));
}

- (void)enter
{
    self.count++;
    dispatch_group_enter(self.group);
}

- (void)leave
{
    self.count--;
    dispatch_group_leave(self.group);
}

- (void)enterWithUUID:(NSUUID * __unused)uuid
{
    self.count++;
    NSArray *callstack = [NSThread  callStackSymbols];
    
    dispatch_async(self.logQueue, ^{
        NSMutableString *log = [NSMutableString stringWithFormat:@"\n\nEntering group %p at:\n", self];
        NSString *stacktrace = [callstack componentsJoinedByString:@"\n"];
        
        if (stacktrace != nil) {
            [log appendString:stacktrace];
        } else {
            [log appendString:@"<empty stack trace>"];
        }
        
        [self.logs setObject:log forKey:uuid.UUIDString];
    });
    dispatch_group_enter(self.group);
}

- (void)leaveWithUUID:(NSUUID *)uuid
{
    self.count--;
    
    dispatch_async(self.logQueue, ^{
        [self.logs removeObjectForKey:uuid.UUIDString];
    });

    dispatch_group_leave(self.group);
}

- (void)notifyOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    dispatch_group_notify(self.group, queue, block);
}

- (void)asyncOnQueue:(dispatch_queue_t)queue block:(dispatch_block_t)block
{
    dispatch_group_async(self.group, queue, block);
}

@end
