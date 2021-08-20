// ReactNativeStripeTerminalV2.m

#import "ReactNativeStripeTerminalV2.h"
#import <StripeTerminal/StripeTerminal.h>
#import <React/RCTConvert.h>

@implementation ReactNativeStripeTerminalV2

NSString *const ACTION_IN_PROGRESS = @"ACTION_IN_PROGRESS";
NSString *const CANNOT_CANCEL_ACTION = @"CANNOT_CANCEL_ACTION";
NSString *const EXECUTE_ACTION_ERROR = @"EXECUTE_ACTION_ERROR";
NSString *const CANCEL_ACTION_ERROR = @"CANCEL_ACTION_ERROR";
NSString *const READER_ALREADY_CONNECTED = @"READER_ALREADY_CONNECTED";
NSString *const READER_NOT_CONNECTED = @"READER_NOT_CONNECTED";

NSString *const INVALID_PAYMENT_INTENT = @"INVALID_PAYMENT_INTENT";
NSString *const SET_TOKEN_ERROR = @"SET_TOKEN_ERROR";

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
        @"onStripeLog",
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
            
            reject(SET_TOKEN_ERROR, @"A problem occured when trying to execute setConnectionToken", error);
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
        return reject(READER_NOT_CONNECTED, @"Can't call createPaymentIntent without connecting a reader", Nil);
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
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to createPaymentIntent", createError);

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
        return reject(READER_NOT_CONNECTED, @"Can't call collectPaymentMethod without connecting a reader", Nil);
    }

    if (self->collectCancelable != Nil) {
        return reject(ACTION_IN_PROGRESS, @"Can't call collectCancelable since it's already in progress", Nil);
    }
    
    self->collectCancelable = [[SCPTerminal shared] collectPaymentMethod:intent completion:^(SCPPaymentIntent *collectResult, NSError *collectError) {
        if (collectError) {
            NSLog(@"collectPaymentMethod failed: %@", collectError);
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to execute collectPaymentMethod", collectError);
        } else {
            NSLog(@"collectPaymentMethod succeeded");
                        
            self->intent = collectResult;
            
            resolve([self serializePaymentIntent:collectResult]);
        }
        
        self->collectCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(cancelCollectPaymentMethod, cancelCollectPaymentMethod:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call cancelReadReusableCard without connecting a reader", Nil);
    }
    
    if (self->collectCancelable == Nil) {
        return reject(CANNOT_CANCEL_ACTION, @"Cannot cancel cancelCollectPaymentMethod since there is no action to cancel", Nil);
    }
    
    [self->collectCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel cancelCollectPaymentMethod", error);
        } else {
            resolve(nil);
        }
    }];
}


RCT_REMAP_METHOD(processPaymentIntent, processPaymentIntent:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call processPaymentIntent without connecting a reader", Nil);
    }

    NSLog(@"Start Process Payment Intent %@", intent);
    
    [[SCPTerminal shared] processPayment:intent completion:^(SCPPaymentIntent *processResult, SCPProcessPaymentError *processError) {
        if (processError) {
            NSLog(@"processPayment failed: %@", processError);

            resolve(@{
                @"error": processError.localizedDescription,
                @"code": @(processError.code),
                @"declineCode": processError.declineCode ? processError.declineCode : @""
            });
        } else {
            NSLog(@"processPayment succeeded");
            
            resolve(@{
                @"intent": [self serializePaymentIntent:processResult]
            });
            
            self->intent = Nil;
            // Notify your backend to capture the PaymentIntent
        }
    }];
}

RCT_REMAP_METHOD(cancelCurrentAction, cancelActions:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    if (self->discoverCancelable != Nil) {
        return [self cancelDiscoverReaders:resolve rejecter:reject];
    }
    
    if (self->collectCancelable != Nil) {
        return [self cancelCollectPaymentMethod:resolve rejecter:reject];
    }
    
    if (self->reusableCancelable != Nil) {
        return [self cancelReadReusableCard:resolve rejecter:reject];
    }
    
    if (self->refundCancelable != Nil) {
        return [self cancelRefundCharge:resolve rejecter:reject];
    }
    
    if (self->updateCancelable != Nil) {
        return [self cancelInstallUpdate:resolve rejecter:reject];
    }
    
    resolve(Nil);
}

RCT_REMAP_METHOD(readReusableCard, reuseOptions:(NSDictionary *)options readReusableCard:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call readReusableCard without connecting a reader", Nil);
    }
    
    if (self->reusableCancelable != Nil) {
        return reject(ACTION_IN_PROGRESS, @"Can't call readReusableCard since it's already in progress", Nil);
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
        if (readError) {
            NSLog(@"readReusableCard failed: %@", readError);
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to execute readReusableCard", readError);
        } else {
            NSLog(@"readReusableCard succeeded");

            resolve([self serializePaymentMethod:readResult]);
        }
        
        self->reusableCancelable = Nil;
    }];
}

RCT_REMAP_METHOD(cancelReadReusableCard, cancelReadReusableCard:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call cancelReadReusableCard without connecting a reader", Nil);
    }
    
    if (self->reusableCancelable == Nil) {
        return reject(CANNOT_CANCEL_ACTION, @"Cannot cancel readReusableCard since there is no action to cancel", Nil);
    }
    
    [self->reusableCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel readReusableCard", error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(cancelInstallUpdate, cancelInstallUpdate:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->updateCancelable == Nil) {
        return reject(CANNOT_CANCEL_ACTION, @"Cannot cancel installUpdate since there is no action to cancel", Nil);
    }
    
    [self->updateCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel installUpdate", error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(discoverReaders, discoverMethod:(NSUInteger) method locationIdentifier:(NSString *) locationID simulatorEnabled:(BOOL) isSimulated discoverReaders:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];

    if (connectionStatus != SCPConnectionStatusNotConnected) {
        return reject(READER_ALREADY_CONNECTED, @"Cannot discover readers when there is a reader already connected", Nil);
    }
    
    if (self->discoverCancelable != Nil) {
        return reject(ACTION_IN_PROGRESS, @"Can't call discoverReaders since it's already in progress", Nil);
    }
    
    SCPDiscoveryConfiguration *config = [[SCPDiscoveryConfiguration alloc] initWithDiscoveryMethod:method locationId:locationID simulated:isSimulated];

    self->discoverCancelable = [[SCPTerminal shared] discoverReaders:config delegate:self completion:^(NSError *error) {
        if (error != nil) {
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to execute discoverReaders", error);

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
        return reject(CANNOT_CANCEL_ACTION, @"Cannot cancel discoverReaders since there is no action to cancel", Nil);
    }
    
    [self->discoverCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel discoverReaders", error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(cancelPaymentIntent, cancelPaymentIntent:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    if (self->intent == Nil) {
        return reject(INVALID_PAYMENT_INTENT, @"Payment intent needs to be selected (using createPaymentIntent or retrievePaymentIntent) before calling cancelPaymentIntent", Nil);
    }
    
    [[SCPTerminal shared] cancelPaymentIntent:self->intent completion:^(SCPPaymentIntent *cancelResult, NSError *cancelError) {
        if (cancelError) {
            NSLog(@"cancelPaymentIntent failed: %@", cancelError);
            
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel discoverReaders", cancelError);
        } else {
            NSLog(@"cancelPaymentIntent succeeded");
            
            resolve([self serializePaymentIntent:cancelResult]);
            
            self->intent = Nil;
        }
    }];
}

RCT_REMAP_METHOD(refundCharge, stripeCharge:(NSString *) charge refundAmount:(int) amount refundOptions:(NSDictionary *)options refundPaymentIntent:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call refundCharge without connecting a reader", Nil);
    }
    
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
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to execute refundCharge, in particular during collectRefundPaymentMethod", collectError);
        } else {
            // Process refund
            [[SCPTerminal shared] processRefund:^(SCPRefund *processResult, SCPProcessRefundError *processError) {
                if (processError) {
                    // Handle process error
                    reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to execute refundCharge, in particular during processRefund", processError);

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
        return reject(CANNOT_CANCEL_ACTION, @"Cannot cancel cancelRefundCharge since there is no action to cancel", Nil);
    }
    
    [self->refundCancelable cancel:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(CANCEL_ACTION_ERROR, @"An error occured while trying to cancel refundCharge", error);
        } else {
            resolve(nil);
        }
    }];
}

RCT_REMAP_METHOD(retrievePaymentIntent, clientSecret:(NSString*)clientSecret retrievePaymentIntent:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    if (connectedReader == Nil) {
        return reject(READER_NOT_CONNECTED, @"Can't call retrievePaymentIntent without connecting a reader", Nil);
    }

    [[SCPTerminal shared] retrievePaymentIntent:clientSecret completion:^(SCPPaymentIntent *retrieveResult, NSError *retrieveError) {
        if (retrieveError) {
            NSLog(@"retrievePaymentIntent failed: %@", retrieveError);
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to retrievePaymentIntent", retrieveError);
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
        return reject(READER_ALREADY_CONNECTED, @"Can't execute connectBluetoothReader since a reader is already connected", Nil);
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
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to connectBluetoothReader", error);
        }
    }];
}

RCT_REMAP_METHOD(connectInternetReader, serialNumber: (NSString *)serialNumber failIfInUse:(BOOL)failIfInUse  allowCustomerCancel:(BOOL)allowCustomerCancel connectBluetoothReader:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];
    
    if (connectionStatus != SCPConnectionStatusNotConnected) {
        return reject(READER_ALREADY_CONNECTED, @"Can't execute connectBluetoothReader since a reader is already connected", Nil);
    }
    
    unsigned long readerIndex = [readers indexOfObjectPassingTest:^(SCPReader *reader, NSUInteger idx, BOOL *stop) {
        return [reader.serialNumber isEqualToString:serialNumber];
    }];

    SCPReader* selectedReader = readers[readerIndex];

    SCPInternetConnectionConfiguration *connectionConfig = [[SCPInternetConnectionConfiguration alloc] initWithFailIfInUse:failIfInUse allowCustomerCancel:allowCustomerCancel];
    
    [[SCPTerminal shared] connectInternetReader:selectedReader connectionConfig:connectionConfig completion:^(SCPReader *reader, NSError *error) {
        if (reader != nil) {
            NSLog(@"Successfully connected to reader: %@", reader);
            
            resolve([self serializeReader:reader]);
        } else {
            NSLog(@"connectBluetoothReader failed: %@", error);
            
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to connectBluetoothReader", error);
        }
    }];
}

RCT_REMAP_METHOD(disconnectReader, disconnectReader:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];
    
    if (connectionStatus != SCPConnectionStatusConnected) {
        return reject(READER_NOT_CONNECTED, @"Cannot disconnect a reader since no readers are currently connected", Nil);
    }
    
    [[SCPTerminal shared] disconnectReader:^(NSError * _Nullable error) {
        if (error != nil) {
            reject(EXECUTE_ACTION_ERROR, @"An error occured while trying to disconnectReader", error);

            reject(@"DISCONENCT REJECT", @"YO WE CANT", error);
        } else {
            NSLog(@"Successfully connected to reader: %@", error);
            resolve(Nil);
        }
    }];
}

RCT_REMAP_METHOD(initialize, verboseLogs:(BOOL) verboseLogs initialize:(RCTPromiseResolveBlock) resolve rejecter:(RCTPromiseRejectBlock) reject) {
    dispatch_once(&onceToken, ^{
        [SCPTerminal setTokenProvider:self];
    });
    
    if (verboseLogs) {
        [SCPTerminal setLogListener:^(NSString *str) {
            [self sendEventWithName:@"onStripeLog" body:@{@"log": str}];
        }];
    }
    
    resolve(Nil);
}

RCT_REMAP_METHOD(getConnectedReader, getConnectedReader:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];

    if (connectionStatus != SCPConnectionStatusNotConnected) {
        return resolve(Nil);
    }

    SCPReader* connectedReader = [[SCPTerminal shared] connectedReader];
    
    resolve([self serializeReader:connectedReader]);
}

RCT_REMAP_METHOD(getPaymentIntent, getPaymentIntent:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self->intent == Nil) {
        return resolve(Nil);
    }
    
    resolve([self serializePaymentIntent:self->intent]);
}

RCT_REMAP_METHOD(getPaymentStatus, getPaymentStatus:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPPaymentStatus paymentStatus = [[SCPTerminal shared] paymentStatus];


    resolve(@{@"statusStr": [SCPTerminal stringFromPaymentStatus:paymentStatus], @"status": @(paymentStatus)});
}

RCT_REMAP_METHOD(getConnectionStatus, getConnectionStatus:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    SCPConnectionStatus connectionStatus = [[SCPTerminal shared] connectionStatus];

    resolve(@{@"statusStr": [SCPTerminal stringFromConnectionStatus:connectionStatus], @"status": @(connectionStatus)});
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
