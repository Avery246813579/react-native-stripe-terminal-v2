// ReactNativeStripeTerminalV2.m

#import "ReactNativeStripeTerminalV2.h"
#import <StripeTerminal/StripeTerminal.h>
#import <React/RCTConvert.h>

@implementation ReactNativeStripeTerminalV2

NSString *const DogTest = @"FirstConstant";

static dispatch_once_t onceToken = 0;

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

RCT_EXPORT_MODULE()

// Will be called when this module's first listener is added.
-(void)startObserving {
    hasListeners = YES;
    // Set up any upstream listeners or background tasks as necessary
}

// Will be called when this module's last listener is removed, or on dealloc.
-(void)stopObserving {
    hasListeners = NO;
    // Remove upstream listeners, stop unnecessary background tasks
}

- (NSArray<NSString *> *)supportedEvents {
    return @[
        @"log",
        @"onRequestConnectionToken",
        @"onReadersDiscovered",
        
        @"onReportUnexpectedReaderDisconnect",
        @"onFinishInstallingUpdate",
        @"onReportAvailableUpdate",
        @"onReportReaderSoftwareUpdateProgress",
        @"onRequestReaderDisplayMessage",
        @"onRequestReaderInput",
        @"onStartInstallingUpdate",
    ];
}

RCT_REMAP_METHOD(setConnectionToken, setConnectionToken:(NSString *)token error:(NSString *)errorMessage resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (pendingConnectionTokenCompletionBlock) {
        if ([errorMessage length] != 0) {
            NSError* error = [NSError errorWithDomain:@"com.stripe-terminal.rn" code:1 userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]];
            
            pendingConnectionTokenCompletionBlock(nil, error);
            
            reject(@"FAIL_CONNECTION", @"Connection has failed", error);
        } else {
            pendingConnectionTokenCompletionBlock(token, nil);
            
            resolve(token);
        }

        pendingConnectionTokenCompletionBlock = nil;
    }
}

RCT_REMAP_METHOD(createPaymentIntent, amount:(NSUInteger) amount currency:(NSString*)currency paymentOptions:(NSDictionary *)options createPaymentIntent:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(@"READER NOT CONNECTED", @"YE GOT NO READER CONNECTED", Nil);
    }
    
    SCPPaymentIntentParameters *params = [[SCPPaymentIntentParameters alloc] initWithAmount:amount currency:currency];
    if (options[@"applicationFeeAmount"]) {
        params.applicationFeeAmount = options[@"applicationFeeAmount"];
    }
    
    if (options[@"onBehalfOf"]) {
        params.onBehalfOf = options[@"onBehalfOf"];
    }
    
    if (options[@"transferDataDestination"]) {
        params.transferDataDestination = options[@"transferDataDestination"];
    }
    
    if (options[@"stripeDescription"]) {
        params.stripeDescription = options[@"stripeDescription"];
    }
    
    if (options[@"statementDescriptor"]) {
        params.statementDescriptor = options[@"statementDescriptor"];
    }

    if (options[@"customer"]) {
        params.customer = options[@"customer"];
    }

    if (options[@"receiptEmail"]) {
        params.receiptEmail = options[@"receiptEmail"];
    }

    if (options[@"transferGroup"]) {
        params.transferGroup = options[@"transferGroup"];
    }

    if (options[@"metadata"]) {
        params.metadata = options[@"metadata"];
    }

    [[SCPTerminal shared] createPaymentIntent:params completion:^(SCPPaymentIntent *createResult, NSError *createError) {
        if (createError) {
            reject(@"event_failure", @"no event id returned", createError);
            NSLog(@"createPaymentIntent failed: %@", createError);
        } else {
            resolve([self serializePaymentIntent:createResult]);
            
            self->intent = createResult;
            NSLog(@"createPaymentIntent succeeded %@", createResult);
            // ...
        }
    }];
}

RCT_REMAP_METHOD(collectPaymentMethod, collectPaymentMethod:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(@"READER NOT CONNECTED", @"YE GOT NO READER CONNECTED", Nil);
    }

    if (self->collectCancelable != Nil) {
        return reject(@"ERROR_COMING_SOON", @"Collect in progress", Nil);
    }
    
    self->collectCancelable = [[SCPTerminal shared] collectPaymentMethod:intent completion:^(SCPPaymentIntent *collectResult, NSError *collectError) {
        NSLog(@"Inside Collect Payment");
        
        if (collectError) {
            NSLog(@"collectPaymentMethod failed: %@", collectError);
            reject(@"DONE GOOFED", @"SHE DONE GOOFED IT UP", collectError);
        } else {
            NSLog(@"collectPaymentMethod succeeded");
                        
            self->intent = collectResult;
            resolve([self serializePaymentIntent:collectResult]);
            // ... Process the payment
        }
        
        self->collectCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(processPaymentIntent, processPaymentIntent:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(@"READER NOT CONNECTED", @"YE GOT NO READER CONNECTED", Nil);
    }

    NSLog(@"Start Process Payment Intent %@", intent);
    
    [[SCPTerminal shared] processPayment:intent completion:^(SCPPaymentIntent *processResult, SCPProcessPaymentError *processError) {
        NSLog(@"INSIDE PROCESS PAYMENT");
        
        if (processError) {
            reject(@"BIG OOF", @"WE COULD NOT PROCESS", processError);
            
            NSLog(@"processPayment failed: %@", processError);
        } else {
            NSLog(@"processPayment succeeded");
            resolve([self serializePaymentIntent:processResult]);
            // Notify your backend to capture the PaymentIntent
        }
    }];
}

RCT_REMAP_METHOD(readReusableCard, reuseOptions:(NSDictionary *)options readReusableCard:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(@"READER NOT CONNECTED", @"YE GOT NO READER CONNECTED", Nil);
    }
    
    if (self->reusableCancelable != Nil) {
        return reject(@"READER NOT CONNECTED", @"WE ALREADY DOING REUSE CARD", Nil);
    }
    
    NSLog(@"Start Reader Reusable Card");
    
    SCPReadReusableCardParameters *params = [SCPReadReusableCardParameters new];
    if (options[@"customer"]) {
        params.customer = options[@"customer"];
    }
    
    if (options[@"metadata"]) {
        params.metadata = options[@"metadata"];
    }

    self->reusableCancelable = [[SCPTerminal shared] readReusableCard:params completion:^(SCPPaymentMethod *readResult, NSError *readError) {
        NSLog(@"Super Sus");
        
        if (readError) {
            NSLog(@"readReusableCard failed: %@", readError);
            
            reject(@"REUSEERROR", @"OOF", readError);
        } else {
            NSLog(@"readReusableCard succeeded");

            resolve([self serializePaymentMethod:readResult]);
        }
        
        self->reusableCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(cancelReadReusableCard, cancelReadReusableCard:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->reusableCancelable == Nil) {
        return reject(@"OH_CRICKY", @"WE CANT CANCEL REUSE", Nil);
    }
    
    [self->reusableCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(@"OH_CRICKY", @"HOW", Nil);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(cancelInstallUpdate, cancelInstallUpdate:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->updateCancelable == Nil) {
        return reject(@"OH_CRICKY", @"WE CANT CANCEL REUSE", Nil);
    }
    
    [self->updateCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(@"OH_CRICKY", @"HOW", Nil);
        } else {
            resolve(nil);
        }
    }];
}


RCT_REMAP_METHOD(discoverReaders, discoverMethod:(NSUInteger) method locationIdentifier:(NSString *) locationID simulatorEnabled:(BOOL) isSimulated discoverReaders:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    
    NSLog(@"HERE DOG %@", self->discoverCancelable);
    if ([[SCPTerminal self] connectedReader] != Nil) {
        return reject(@"OH_CRICKY", @"READER IS ALREADY CONNECTED", Nil);
    }
    
    if (self->discoverCancelable != Nil) {
        return reject(@"OH_CRICKY", @"YOU DONE GOOFED", Nil);
    }
    
    SCPDiscoveryConfiguration *config = [[SCPDiscoveryConfiguration alloc] initWithDiscoveryMethod:method locationId:locationID simulated:isSimulated];

    self->discoverCancelable = [[SCPTerminal shared] discoverReaders:config delegate:self completion:^(NSError *error) {
        NSLog(@"Dogs are really fun");
        
        if (error != nil) {
            reject(@"ERROR", @"Fail", error);

            NSLog(@"discoverReaders failed: %@", error);
        } else {
            resolve(@"Success");

            NSLog(@"discoverReaders succeeded");
        }
        
        self->discoverCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(cancelDiscoverReaders, cancelDiscoverReaders:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->discoverCancelable == Nil) {
        return reject(@"OH_CRICKY", @"YOU DONE GOOFED", Nil);
    }
    
    [self->discoverCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(@"OH_CRICKY", @"YOU DONE GOOFED", Nil);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(cancelPaymentIntent, cancelPaymentIntent:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->intent == Nil) {
        return reject(@"OH_CRICKY", @"YOU DONE GOOFED MY DOG", Nil);
    }
    
    [[SCPTerminal shared] cancelPaymentIntent:self->intent completion:^(SCPPaymentIntent *cancelResult, NSError *cancelError) {
        if (cancelError) {
            NSLog(@"cancelPaymentIntent failed: %@", cancelError);
        }
        else {
            NSLog(@"cancelPaymentIntent succeeded");
        }
    }];
}


RCT_REMAP_METHOD(refundCharge, stripeCharge:(NSString *) charge refundAmount:(int) amount refundOptions:(NSDictionary *)options refundPaymentIntent:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    NSString * currencyOverride = @"USD";
    
    if (options[@"currency"]) {
        currencyOverride = options[@"currency"];
    }
    
    SCPRefundParameters *refundParams =  [[SCPRefundParameters alloc] initWithChargeId:charge amount:amount currency:currencyOverride];
    if (options[@"reverseTransfer"]) {
        refundParams.reverseTransfer = options[@"reverseTransfer"];
    }
    
    if (options[@"metadata"]) {
        refundParams.metadata = options[@"metadata"];
    }

    if (options[@"refundApplicationFee"]) {
        refundParams.refundApplicationFee = options[@"refundApplicationFee"];
    }

    self->refundCancelable = [[SCPTerminal shared] collectRefundPaymentMethod:refundParams completion:^(NSError *collectError) {
        if (collectError) {
            // Handle collect error
            NSLog(@"collectRefundPaymentMethod failed: %@", collectError);
            
            reject(@"REFUND_ERRIR", @"collectRefundPaymentMethod failed.", collectError);
        } else {
            // Process refund
            [[SCPTerminal shared] processRefund:^(SCPRefund *processResult, SCPProcessRefundError *processError) {
                if (processError) {
                    // Handle process error
                    reject(@"REFUND_ERRIR", @"processRefund failed.", processError);

                    NSLog(@"processRefund failed: %@", processError);
                } else if (processResult) {
                    if (processResult.status == SCPRefundStatusSucceeded) {
                        resolve(processResult);
                        
                        NSLog(@"Process refund successful! %@", processResult);
                    } else {
                        reject(@"REFUND_ERRIR", @"Refund pending or unsuccessful.", Nil);
                        
                        NSLog(@"Refund pending or unsuccessful.");
                    }
                }
            }];
        }
        
        self->refundCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(cancelRefundCharge, cancelRefundCharge:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->refundCancelable == Nil) {
        return reject(@"OH_CRICKY", @"YOU DONE GOOFED", Nil);
    }
    
    [self->refundCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(@"OH_CRICKY", @"YOU DONE GOOFED", Nil);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(retrievePaymentIntent, clientSecret:(NSString*)clientSecret retrievePaymentIntent:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    [[SCPTerminal shared] retrievePaymentIntent:clientSecret completion:^(SCPPaymentIntent *retrieveResult, NSError *retrieveError) {
        if (retrieveError) {
            NSLog(@"retrievePaymentIntent failed: %@", retrieveError);
            
            reject(@"YO", @"retrievePaymentIntent failed: %@", retrieveError);
        }
        else {
            NSLog(@"retrievePaymentIntent succeeded");
            
            self->intent = retrieveResult;
            
            resolve([self serializePaymentIntent:retrieveResult]);
        }
    }];
}

RCT_REMAP_METHOD(connectBluetoothReader, reader: (NSString *)serialNumber locationID: (NSString *)locationID connectBluetoothReader:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];
    
    if (connectionStatus != SCPConnectionStatusNotConnected) {
        return reject(@"STATUS", @"TO COME", Nil);
    }
    
    unsigned long readerIndex = [readers indexOfObjectPassingTest:^(SCPReader *reader, NSUInteger idx, BOOL *stop) {
        return [reader.serialNumber isEqualToString:serialNumber];
    }];

    SCPReader* selectedReader = readers[readerIndex];

    SCPBluetoothConnectionConfiguration *connectionConfig = [[SCPBluetoothConnectionConfiguration alloc] initWithLocationId: locationID];
    
    [[SCPTerminal shared] connectBluetoothReader:selectedReader delegate:self connectionConfig:connectionConfig completion:^(SCPReader *reader, NSError *error) {
        if (reader != nil) {
            NSLog(@"Successfully connected to reader: %@", reader);
            resolve([self serializeReader:reader]);
        } else {
            NSLog(@"connectBluetoothReader failed: %@", error);
            reject(@"OOF", @"@OOF", error);
        }
    }];
}

RCT_REMAP_METHOD(connectInternetReader, serialNumber: (NSString *)serialNumber failIfInUse:(BOOL)failIfInUse  allowCustomerCancel:(BOOL)allowCustomerCancel connectBluetoothReader:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];
    
    if (connectionStatus != SCPConnectionStatusNotConnected) {
        return NSLog(@"We here bruv");
    }
    
    unsigned long readerIndex = [readers indexOfObjectPassingTest:^(SCPReader *reader, NSUInteger idx, BOOL *stop) {
        return [reader.serialNumber isEqualToString:serialNumber];
    }];

    SCPReader* selectedReader = readers[readerIndex];

    SCPInternetConnectionConfiguration *connectionConfig = [[SCPInternetConnectionConfiguration alloc] initWithFailIfInUse:failIfInUse allowCustomerCancel:allowCustomerCancel];
    
    [[SCPTerminal shared] connectInternetReader:selectedReader connectionConfig:connectionConfig completion:^(SCPReader *reader, NSError *error) {
        if (reader != nil) {
            NSLog(@"Successfully connected to reader: %@", reader);
        } else {
            NSLog(@"connectBluetoothReader failed: %@", error);
        }
    }];
}

RCT_REMAP_METHOD(disconnectReader, disconnectReader:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];
    
    if (connectionStatus != SCPConnectionStatusConnected) {
        return reject(@"DISCONENCT REJECT", @"CANT DISCONNECT IF YOU AINT EVER CONNECTED", Nil);
    }
    
    [[SCPTerminal shared] disconnectReader:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"connectBluetoothReader failed: %@", error);
            
            reject(@"DISCONENCT REJECT", @"YO WE CANT", error);
        } else {
            NSLog(@"Successfully connected to reader: %@", error);
            resolve(Nil);
        }
    }];
}

RCT_REMAP_METHOD(initialize, initialize:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    dispatch_once(&onceToken, ^{
        [SCPTerminal setTokenProvider:self];
    });
    
//    [SCPTerminal setLogListener:^(NSString *str) {
//        NSLog(@"Stripe logs %@", str);
//    }];
    
    resolve(@YES);
}

- (void)fetchConnectionToken:(nonnull SCPConnectionTokenCompletionBlock)completion {
    pendingConnectionTokenCompletionBlock = completion;
    
    NSLog(@"Fetching Token");
    [self sendEventWithName:@"onRequestConnectionToken" body:@{}];
}

- (void)terminal:(SCPTerminal *)terminal didUpdateDiscoveredReaders:(NSArray<SCPReader *>*)_readers {
    // Only connect if we aren't currently connected.
    
    readers = _readers;

    NSMutableArray *data = [NSMutableArray arrayWithCapacity:[readers count]];
    [readers enumerateObjectsUsingBlock:^(SCPReader *reader, NSUInteger idx, BOOL *stop) {
        [data addObject:[self serializeReader:reader]];
    }];

    [self sendEventWithName:@"onReadersDiscovered" body:data];
}

- (void)terminal:(nonnull SCPTerminal *)terminal didReportUnexpectedReaderDisconnect:(nonnull SCPReader *)reader {
    [self sendEventWithName:@"onReportUnexpectedReaderDisconnect" body:@{
        @"reader": [self serializeReader:reader]
    }];
}

- (void)reader:(nonnull SCPReader *)reader didFinishInstallingUpdate:(nullable SCPReaderSoftwareUpdate *)update error:(nullable NSError *)error {
    [self sendEventWithName:@"onFinishInstallingUpdate" body:@{
        @"reader": [self serializeReader:reader],
        @"update": [self serializeReaderSoftwareUpdate:update]
    }];
}

- (void)reader:(nonnull SCPReader *)reader didReportAvailableUpdate:(nonnull SCPReaderSoftwareUpdate *)update {
    [self sendEventWithName:@"onReportAvailableUpdate" body:@{
        @"reader": [self serializeReader:reader],
        @"update": [self serializeReaderSoftwareUpdate:update]
    }];
}

- (void)reader:(nonnull SCPReader *)reader didReportReaderSoftwareUpdateProgress:(float)progress {
    [self sendEventWithName:@"onReportReaderSoftwareUpdateProgress" body:@{
        @"reader": [self serializeReader:reader],
        @"progress": @(progress)
    }];
}

- (void)reader:(nonnull SCPReader *)reader didRequestReaderDisplayMessage:(SCPReaderDisplayMessage)displayMessage {
    [self sendEventWithName:@"onRequestReaderDisplayMessage" body:@{
        @"reader": [self serializeReader:reader],
        @"message": [SCPTerminal stringFromReaderDisplayMessage:displayMessage],
    }];
}

- (void)reader:(nonnull SCPReader *)reader didRequestReaderInput:(SCPReaderInputOptions)inputOptions {
    [self sendEventWithName:@"onRequestReaderInput" body:@{
        @"reader": [self serializeReader:reader],
        @"text": [SCPTerminal stringFromReaderInputOptions:inputOptions]
    }];
}

- (void)reader:(nonnull SCPReader *)reader didStartInstallingUpdate:(nonnull SCPReaderSoftwareUpdate *)update cancelable:(nullable SCPCancelable *)cancelable {
    self->updateCancelable = cancelable;
    
    [self sendEventWithName:@"onStartInstallingUpdate" body:@{
        @"reader": [self serializeReader:reader],
        @"update": [self serializeReaderSoftwareUpdate:update]
    }];

}

- (NSDictionary *) serializePaymentIntent:(SCPPaymentIntent *)intent {
    NSMutableArray *mutableArray = [NSMutableArray new];
    
    [intent.charges enumerateObjectsUsingBlock:^(SCPCharge * charge, NSUInteger index, BOOL *stop) {
        // Body of the function
        [mutableArray addObject:(@{
            @"amount": @(charge.amount)
        })];
    }];
    
    return @{
        @"id": intent.stripeId,
        @"created": intent.created,
        @"status": @(intent.status),
        @"amount": @(intent.amount),
        @"currency": intent.currency,
        @"metadata": intent.metadata,
        @"charges": mutableArray
    };
}

- (NSDictionary *) serializePaymentMethod:(SCPPaymentMethod *) method {
    return @{
        @"id": method.stripeId,
        @"card": method.card,
        @"created": method.created,
        @"type": @(method.type),
        @"customer": method.customer ? method.customer : @"",
        @"metadata": method.metadata,
    };
}

- (NSDictionary *) serializeReader:(SCPReader *) reader {
    return @{
        @"batteryLevel": reader.batteryLevel ? reader.batteryLevel : @(0),
        @"deviceType": @(reader.deviceType),
        @"deviceTypeStr": [SCPTerminal stringFromDeviceType: reader.deviceType],
        @"serialNumber": reader.serialNumber ? reader.serialNumber : @"",
        @"deviceSoftwareVersion": reader.deviceSoftwareVersion ? reader.deviceSoftwareVersion : @""
    };
}

- (NSDictionary *) serializeReaderSoftwareUpdate:(SCPReaderSoftwareUpdate *) update {
    
    return @{
        @"requiredAt": update.requiredAt,
        @"version": update.deviceSoftwareVersion,
        @"estimatedUpdateTime": [SCPReaderSoftwareUpdate stringFromUpdateTimeEstimate:(SCPUpdateTimeEstimate)update.estimatedUpdateTime]
    };
}

@end
