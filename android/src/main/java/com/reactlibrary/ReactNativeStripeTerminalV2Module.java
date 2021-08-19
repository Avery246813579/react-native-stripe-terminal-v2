// ReactNativeStripeTerminalV2Module.java

package com.reactlibrary;

import android.Manifest;
import android.content.pm.PackageManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;
import com.stripe.stripeterminal.Terminal;
import com.stripe.stripeterminal.external.callable.BluetoothReaderListener;
import com.stripe.stripeterminal.external.callable.Callback;
import com.stripe.stripeterminal.external.callable.Cancelable;
import com.stripe.stripeterminal.external.callable.ConnectionTokenCallback;
import com.stripe.stripeterminal.external.callable.ConnectionTokenProvider;
import com.stripe.stripeterminal.external.callable.PaymentIntentCallback;
import com.stripe.stripeterminal.external.callable.ReaderCallback;
import com.stripe.stripeterminal.external.callable.TerminalListener;
import com.stripe.stripeterminal.external.models.ConnectionConfiguration;
import com.stripe.stripeterminal.external.models.ConnectionStatus;
import com.stripe.stripeterminal.external.models.ConnectionTokenException;
import com.stripe.stripeterminal.external.models.DiscoveryConfiguration;
import com.stripe.stripeterminal.external.models.DiscoveryMethod;
import com.stripe.stripeterminal.external.models.PaymentIntent;
import com.stripe.stripeterminal.external.models.PaymentIntentParameters;
import com.stripe.stripeterminal.external.models.PaymentStatus;
import com.stripe.stripeterminal.external.models.Reader;
import com.stripe.stripeterminal.external.models.ReaderDisplayMessage;
import com.stripe.stripeterminal.external.models.ReaderEvent;
import com.stripe.stripeterminal.external.models.ReaderInputOptions;
import com.stripe.stripeterminal.external.models.ReaderSoftwareUpdate;
import com.stripe.stripeterminal.external.models.TerminalException;
import com.stripe.stripeterminal.log.LogLevel;

import org.jetbrains.annotations.NotNull;

import java.text.SimpleDateFormat;
import java.util.Date;

public class ReactNativeStripeTerminalV2Module extends ReactContextBaseJavaModule implements ConnectionTokenProvider, TerminalListener, BluetoothReaderListener {
    public static final String EVENT_REQUEST_CONNECTION_TOKEN = "requestConnectionToken";

    public static final String ERROR = "error";
    public static final String CODE = "code";
    public static final String BATTERY_LEVEL = "batteryLevel";
    public static final String DEVICE_TYPE = "deviceType";
    public static final String SERIAL_NUMBER = "serialNumber";
    public static final String DEVICE_SOFTWARE_VERSION = "deviceSoftwareVersion";
    public static final String STATUS = "status";
    public static final String EVENT = "event";
    public static final String INFO = "info";
    public static final String PAYMENT_INTENT = "paymentIntent";
    public static final String AMOUNT = "amount";
    public static final String CURRENCY = "currency";
    public static final String APPLICATION_FEE_AMOUNT = "applicationFeeAmount";
    public static final String TEXT = "text";
    public static final String STRIPE_ID = "stripeId";
    public static final String CREATED = "created";
    public static final String METADATA = "metadata";
    public static final String INTENT = "intent";
    public static final String DECLINE_CODE = "declineCode";
    public static final String ESTIMATED_UPDATE_TIME = "estimatedUpdateTime";
    public static final String ON_BEHALF_OF = "onBehalfOf";
    public static final String TRANSFER_DATA_DESTINATION = "transferDataDestination";
    public static final String TRANSFER_GROUP = "transferGroup";
    public static final String CUSTOMER = "customer";
    public static final String DESCRIPTION = "description";
    public static final String STATEMENT_DESCRIPTOR = "statementDescriptor";
    public static final String STATEMENT_DESCRIPTOR_SUFFIX = "statementDescriptorSuffix";
    public static final String RECEIPT_EMAIL = "receiptEmail";
    public static final String UPDATE = "update";

    private final ReactApplicationContext reactContext;

    ConnectionTokenCallback pendingConnectionTokenCallback = null;
    ReaderEvent lastReaderEvent = ReaderEvent.CARD_REMOVED;
    PaymentIntent paymentIntent = null;

    ReactContext getContext() {
        return getReactApplicationContext();
    }

    public void sendEventWithName(String eventName, WritableMap eventData) {
        getContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, eventData);
    }

    public void sendEventWithName(String eventName, Object eventData) {
        getContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, eventData);
    }

    public void sendEventWithName(String eventName, WritableArray eventData) {
        getContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
                .emit(eventName, eventData);
    }

    public ReactNativeStripeTerminalV2Module(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
    }

    @ReactMethod
    public void setConnectionToken(String token, String errorMsg) {
        if (pendingConnectionTokenCallback != null) {
            if (errorMsg != null && !errorMsg.trim().isEmpty()) {
                pendingConnectionTokenCallback.onFailure(new ConnectionTokenException(errorMsg));
            } else {
                pendingConnectionTokenCallback.onSuccess(token);
            }
        }

        pendingConnectionTokenCallback = null;
    }

    @ReactMethod
    public void createPaymentIntent(Promise promise) {
        PaymentIntentParameters params = new PaymentIntentParameters.Builder()
                .setAmount(1000)
                .setCurrency("usd")
                .build();

        Terminal.getInstance().createPaymentIntent(params, new PaymentIntentCallback() {
            @Override
            public void onSuccess(@NonNull PaymentIntent _paymentIntent) {
                paymentIntent = _paymentIntent;

                promise.resolve(serializePaymentIntent(paymentIntent, "USD"));
            }

            @Override
            public void onFailure(TerminalException exception) {
                // Placeholder for handling exception
            }
        });
    }


    @ReactMethod
    public void collectPaymentIntent(Promise promise) {
        Cancelable cancelable = Terminal.getInstance().collectPaymentMethod(paymentIntent, new PaymentIntentCallback() {
            @Override
            public void onSuccess(@NonNull PaymentIntent _paymentIntent) {
                paymentIntent = _paymentIntent;

                promise.resolve(serializePaymentIntent(_paymentIntent, "USD"));
            }

            @Override
            public void onFailure(TerminalException exception) {
                // Placeholder for handling exception
            }
        });
    }

    @ReactMethod
    public void processPaymentIntent(Promise promise) {
        Terminal.getInstance().processPayment(paymentIntent,
                new PaymentIntentCallback() {
                    @Override
                    public void onSuccess(PaymentIntent _paymentIntent) {
                        promise.resolve(serializePaymentIntent(_paymentIntent, "USD"));
                        // Placeholder for notifying your backend to capture paymentIntent.id
                    }

                    @Override
                    public void onFailure(TerminalException exception) {
                        // Placeholder for handling the exception
                    }
                });
    }

    public void discoverReaders() {
        DiscoveryConfiguration config = new DiscoveryConfiguration(0, DiscoveryMethod.BLUETOOTH_SCAN, false);

        Terminal.getInstance().discoverReaders(
                config,
                readers -> {
                    // Just select the first reader here.
                    Reader firstReader = readers.get(0);

                    // When connecting to a physical reader, your integration should specify either the
                    // same location as the last connection (selectedReader.getLocation().getId()) or a new location
                    // of your user's choosing.
                    //
                    // Since the simulated reader is not associated with a real location, we recommend
                    // specifying its existing mock location.
                    ConnectionConfiguration.BluetoothConnectionConfiguration connectionConfig =
                            new ConnectionConfiguration.BluetoothConnectionConfiguration("tml_DzDeZgFF76H5lT");

                    Terminal.getInstance().connectBluetoothReader(
                            firstReader,
                            connectionConfig,
                            this,
                            new ReaderCallback() {
                                @Override
                                public void onSuccess(@NotNull Reader reader) {
                                    System.out.println("Connected to reader" + reader.getSerialNumber());
                                }

                                @Override
                                public void onFailure(@NotNull TerminalException e) {
                                    e.printStackTrace();
                                }
                            }
                    );
                },
                new Callback() {
                    @Override
                    public void onSuccess() {
                        System.out.println("Finished discovering readers");
                    }

                    @Override
                    public void onFailure(@NotNull TerminalException e) {
                        e.printStackTrace();
                    }
                }
        );
    }

    @ReactMethod
    public void initialize(com.facebook.react.bridge.Promise callback) {
        System.out.println("Hello my dear");

        try {
            Terminal.getInstance();

            WritableMap writableMap = Arguments.createMap();
            writableMap.putBoolean("isInitialized", true);
            callback.resolve(writableMap);
            return;
        } catch (IllegalStateException e) {
        }

        pendingConnectionTokenCallback = null;

        LogLevel logLevel = LogLevel.VERBOSE;
        ConnectionTokenProvider tokenProvider = this;
        TerminalListener terminalListener = this;
        String err = "";
        boolean isInit = false;
        try {
            Terminal.initTerminal(getContext().getApplicationContext(), logLevel, tokenProvider, terminalListener);
            lastReaderEvent = ReaderEvent.CARD_REMOVED;
            isInit = true;
        } catch (TerminalException e) {
            e.printStackTrace();
            err = e.getErrorMessage();
            isInit = false;
        } catch (IllegalStateException ex) {
            ex.printStackTrace();
            err = ex.getMessage();
            isInit = true;
        }

        WritableMap writableMap = Arguments.createMap();
        writableMap.putBoolean("isInitialized", isInit);

        if (!isInit) {
            writableMap.putString(ERROR, err);
        } else {
            discoverReaders();
        }

        callback.resolve(writableMap);
    }


    @Override
    public void fetchConnectionToken(@NonNull ConnectionTokenCallback connectionTokenCallback) {
        pendingConnectionTokenCallback = connectionTokenCallback;

        sendEventWithName(EVENT_REQUEST_CONNECTION_TOKEN, Arguments.createMap());
    }

    @Override
    public void onConnectionStatusChange(@NonNull ConnectionStatus connectionStatus) {

    }

    @Override
    public void onPaymentStatusChange(@NonNull PaymentStatus paymentStatus) {

    }

    @Override
    public void onUnexpectedReaderDisconnect(@NonNull Reader reader) {

    }

    @Override
    public void onFinishInstallingUpdate(@Nullable ReaderSoftwareUpdate readerSoftwareUpdate, @Nullable TerminalException e) {

    }

    @Override
    public void onReportAvailableUpdate(@NonNull ReaderSoftwareUpdate readerSoftwareUpdate) {

    }

    @Override
    public void onReportLowBatteryWarning() {

    }

    @Override
    public void onReportReaderEvent(@NonNull ReaderEvent readerEvent) {

    }

    @Override
    public void onReportReaderSoftwareUpdateProgress(float v) {

    }

    @Override
    public void onRequestReaderDisplayMessage(@NonNull ReaderDisplayMessage readerDisplayMessage) {

    }

    @Override
    public void onRequestReaderInput(@NonNull ReaderInputOptions readerInputOptions) {

    }

    @Override
    public void onStartInstallingUpdate(@NonNull ReaderSoftwareUpdate readerSoftwareUpdate, @Nullable Cancelable cancelable) {

    }

    @Override
    public String getName() {
        return "ReactNativeStripeTerminalV2";
    }

    WritableMap serializePaymentIntent(PaymentIntent paymentIntent, String currency) {
        WritableMap paymentIntentMap = Arguments.createMap();
        paymentIntentMap.putString(STRIPE_ID, paymentIntent.getId());
        SimpleDateFormat simpleDateFormat = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZZZZ");
        paymentIntentMap.putString(CREATED, simpleDateFormat.format(new Date(paymentIntent.getCreated())));
        paymentIntentMap.putInt(STATUS, paymentIntent.getStatus().ordinal());
        paymentIntentMap.putInt(AMOUNT, (int) paymentIntent.getAmount());
        paymentIntentMap.putString(CURRENCY, currency);
        WritableMap metaDataMap = Arguments.createMap();
        if (paymentIntent.getMetadata() != null) {
            for (String key : paymentIntent.getMetadata().keySet()) {
                metaDataMap.putString(key, String.valueOf(paymentIntent.getMetadata().get(key)));
            }
        }
        paymentIntentMap.putMap(METADATA, metaDataMap);
        return paymentIntentMap;
    }

}
