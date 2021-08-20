// main index.js

import {NativeModules, NativeEventEmitter} from "react-native";

const {ReactNativeStripeTerminalV2} = NativeModules;

const {
  checkPermissions: _checkPermissions,
  discoverReaders: _discoverReaders,
  connectInternetReader: _connectInternetReader,
  initialize: _initialize,
  setConnectionToken: _setConnectionToken,
  createPaymentIntent: _createPaymentIntent,
  connectBluetoothReader: _connectBluetoothReader,
  cancelDiscoverReaders: _cancelDiscoverReaders,
  processPaymentIntent: _processPaymentIntent,
  collectPaymentMethod: _collectPaymentMethod,
  retrievePaymentIntent: _retrievePaymentIntent,
  cancelReadReusableCard: _cancelReadReusableCard,
  readReusableCard: _readReusableCard,
  refundCharge: _refundCharge,
  cancelRefundCharge: _cancelRefundCharge,
  disconnectReader: _disconnectReader,
  cancelInstallUpdate: _cancelInstallUpdate,

  cancelCurrentAction: _cancelCurrentAction,
  cancelCollectPaymentMethod: _cancelCollectPaymentMethod,
  getConnectedReader: _getConnectedReader,
  getPaymentIntent: _getPaymentIntent,
  getPaymentStatus: _getPaymentStatus,
  getConnectionStatus: _getConnectionStatus,

  cancelPaymentIntent: _cancelPaymentIntent,
} = ReactNativeStripeTerminalV2;

const listeners = new NativeEventEmitter(ReactNativeStripeTerminalV2);

export const DISCOVERY_METHOD = {
  BLUETOOTH_PROXIMITY: 0,
  BLUETOOTH_SCAN: 1,
  INTERNET: 2,
};

listeners.addListener("onRequestConnectionToken", async () => {
  if (defaultOptions.fetchConnectionToken === null) {
    throw new Error("FETCH_CONNECTION_INVALID", "fetchConnectionToken has to be defined inside the initialize method");
  }

  const secret = await defaultOptions.fetchConnectionToken();

  _setConnectionToken(secret, null);
});

const defaultOptions = {
  fetchConnectionToken: null,
};

/**
 *
 * @param options
 * @param options.fetchConnectionToken
 * @param options.verboseLogs
 *
 * @return {Promise<*>}
 */
export async function initialize(options = {}) {
  const {fetchConnectionToken = null, verboseLogs = false} = options;

  if (fetchConnectionToken === null) {
    throw new Error("FETCH_CONNECTION_INVALID", "fetchConnectionToken has to be defined inside the initialize method");
  }

  defaultOptions.fetchConnectionToken = fetchConnectionToken;

  return _initialize(verboseLogs);
}

export async function checkPermissions() {
  return _checkPermissions();
}

/**
 *
 * @param options
 * @param options.amount
 * @param options.currency
 * @param options.customer
 * @param options.onBehalfOf
 * @param options.receiptEmail
 * @param options.description
 * @param options.statementDescriptor
 * @param options.applicationFeeAmount
 * @param options.transferDataDestination
 * @param options.stripeDescription
 * @param options.statementDescriptor
 * @param options.metadata
 * @param options.transferGroup
 *
 * @return {Promise<*>}
 */
export async function createPaymentIntent(options = {}) {
  const {
    amount = 1000,
    currency = "USD",
    applicationFeeAmount,
    transferDataDestination = null,
    onBehalfOf = null,
    description,
  } = options;

  if (description) {
    options.stripeDescription = description;
  }

  if (
    applicationFeeAmount &&
    (transferDataDestination === null || onBehalfOf === null)
  ) {
    return Promise.reject({error: "APPLICATION_FEE_ERROR",  message: "Both need to be set"});
  }

  if (transferDataDestination && onBehalfOf === null || transferDataDestination === null && onBehalfOf) {
    return Promise.reject({error: "ON_BEHALF_ERROR",  message: "Both need to be set"});
  }

  return _createPaymentIntent(amount, currency, options);
}

/**
 *
 * @param charge
 * @param amount
 * @param options
 * @param options.reverseTransfer
 * @param options.metadata
 * @param options.currency
 * @param options.refundApplicationFee
 *
 * @return {Promise<void>}
 */
export async function refundCharge(charge, amount, options) {
  _refundCharge(charge, amount, options);
}

export async function cancelRefundCharge() {
  _cancelRefundCharge();
}

/**
 *
 *
 * @param options
 * @param options.customer
 * @param options.metadata
 *
 * @return {Promise<*>}
 */
export async function readReusableCard(options = {}) {
  return _readReusableCard(options);
}

export async function cancelReadReusableCard() {
  return _cancelReadReusableCard();
}

export async function cancelInstallUpdate() {
  return _cancelInstallUpdate();
}

export async function retrievePaymentIntent(payment) {
  return _retrievePaymentIntent(payment);
}

export async function collectPaymentMethod(options) {
  return _collectPaymentMethod();
}

export async function processPaymentIntent() {
  const processResponse = await _processPaymentIntent();

  if (processResponse.error) {
    return Promise.reject(processResponse);
  }

  return processResponse.intent;
}

export async function connectBluetoothReader(reader, location) {
  return _connectBluetoothReader(reader, location);
}

export async function disconnectReader() {
  return _disconnectReader();
}

export async function cancelDiscoverReaders() {
  return _cancelDiscoverReaders();
}

/**
 *
 * @param reader
 * @param options
 * @param options.initWithFailIfInUse
 * @param options.allowCustomerCancel
 *
 * @return {Promise<*>}
 */
export async function connectInternetReader(reader, options = {}) {
  const {initWithFailIfInUse = true, allowCustomerCancel = false} = options;

  return _connectInternetReader(
    reader,
    initWithFailIfInUse,
    allowCustomerCancel
  );
}

/**
 *
 * @param params
 * @param params.simulated                      if we are simulated
 * @param params.locationId                     location id for targeted readers
 * @param params.method {DISCOVERY_METHOD}      discover method
 *
 * @return {Promise<*>}
 */
export async function discoverReaders(params) {
  const {
    method = DISCOVERY_METHOD.BLUETOOTH_SCAN,
    simulated = false,
    locationId = null,
  } = params;

  return _discoverReaders(method, locationId, simulated);
}

export async function cancelCurrentAction() {
  return _cancelCurrentAction();
}

export async function cancelCollectPaymentMethod() {
  return _cancelCollectPaymentMethod();
}

export async function cancelPaymentIntent() {
  return _cancelPaymentIntent();
}

export async function getConnectedReader() {
  const connectedReader = await _getConnectedReader();

  if (connectedReader) {
    return connectedReader;
  }

  return null;
}

export async function getPaymentIntent() {
  const paymentIntent = await _getPaymentIntent();

  if (paymentIntent) {
    return paymentIntent;
  }

  return null;
}

export async function getPaymentStatus() {
  return _getPaymentStatus();
}

export async function getConnectionStatus() {
  return _getConnectionStatus();
}

export function registerTerminalListener(key, method) {
  return listeners.addListener(key, method);
}
