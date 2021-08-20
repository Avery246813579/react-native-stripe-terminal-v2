/**
 * Sample React Native App
 *
 * adapted from App.js generated by the following command:
 *
 * react-native init example
 *
 * https://github.com/facebook/react-native
 */

import React, {Component} from "react";
import {Button, ScrollView, StyleSheet, Text, View} from "react-native";
import {
  cancelCurrentAction,
  cancelDiscoverReaders,
  collectPaymentMethod,
  connectBluetoothReader,
  createPaymentIntent,
  disconnectReader,
  discoverReaders,
  getConnectedReader, getConnectionStatus, getPaymentIntent, getPaymentStatus,
  initialize,
  processPaymentIntent,
  readReusableCard,
  refundCharge,
  registerTerminalListener,
  retrievePaymentIntent,
} from "react-native-stripe-terminal-v2";

export default class App extends Component<{}> {
  state = {
    status: "starting",
    message: "--",
  };

  componentDidMount() {
    // if (Platform.OS === "android") {
    //   checkPermissions();
    // }
    this.setupReader();

    registerTerminalListener("onReadersDiscovered", (readers) => {
      if (readers.length > 0) {
        connectBluetoothReader(readers[0].serialNumber, "tml_DzDeZgFF76H5lT")
          .then((data) => {
            console.log("WE DID IT MOM");
          })
          .catch((err) => {
            console.log(err);
          });
      }

      console.log(readers);
    });
  }

  fetchConnectionToken() {
    let headers = {
      "Content-Type": "application/json",
      Accept: "application/json",
    };

    return new Promise((resolve) => {
      fetch("https://api.dripdrinks.co/terminal/token", {
        method: "POST",
        headers: headers,
      })
        .then((response) => response.json())
        .then((responseJson) => {
          if (responseJson["success"]) {
            resolve(responseJson.data.secret);
          }
        });
    });
  }

  setupReader() {
    initialize({
      fetchConnectionToken: this.fetchConnectionToken.bind(this),
    })
      .then((err) => {
        console.log("HERE2", err);
      })
      .catch((err) => {
        console.log(err);
      });
  }

  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome}>
          ☆ReactNativeStripeTerminalV2 example☆
        </Text>

        <ScrollView style={{marginTop: 24}}>
          <Button
            title="Discover Readers"
            onPress={() =>
              discoverReaders({
                simulated: true,
              })
                .then((data) => {
                  console.log(data);
                })
                .catch((err) => {
                  console.log(err);

                  if (err.code === "OH_CRICKY") {
                    cancelDiscoverReaders().then(() => {
                      console.log("WE CANCELLED");
                    });
                  }
                })
            }
          />

          <Button
            title="Create Payment Intent"
            onPress={() =>
              createPaymentIntent({
                amount: 6969,
              })
                .then((data) => {
                  console.log("Create Payment Intent", data);
                })
                .catch((err) => {
                  console.log("Create Payment Intent Error", err);
                })
            }
          />

          <Button
            title="Retrieve Payment Intent"
            onPress={() =>
              retrievePaymentIntent(
                "pi_3JPqavAcqRxm04BK1XUXLQ89_secret_sQESXVyaebGPY5Cn6ZzUX8TFV"
              )
                .then((data) => {
                  console.log("Retrieve Payment Intent", data);
                })
                .catch((err) => {
                  console.log("Retrieve Payment Intent", err);
                })
            }
          />

          <Button
            title="Collect Payment Intent"
            onPress={() =>
              collectPaymentMethod()
                .then((data) => {
                  console.log("Collect Payment Intent", data);
                })
                .catch((err) => {
                  console.log("Collect Payment Intent Error", err);
                })
            }
          />

          <Button
            title="Process Payment Intent"
            onPress={() =>
              processPaymentIntent()
                .then((data) => {
                  console.log("Process Payment Intent", data);
                })
                .catch((err) => {
                  console.log("Process Payment Intent Error", err);
                })
            }
          />

          <Button
            title="Read Reusable Card"
            onPress={() =>
              readReusableCard({metadata: {cats: "cool"}})
                .then((data) => {
                  console.log("Read Reusable Card", data);
                })
                .catch((err) => {
                  console.log("Read Reusable Card Error", err);
                })
            }
          />

          <Button
            title="Refund Charge"
            onPress={() =>
              refundCharge("ch_3JPzBeAcqRxm04BK1GYkzRpI", 1000, {
                metadata: {cats: "cool"},
              })
                .then((data) => {
                  console.log("Refund Charge", data);
                })
                .catch((err) => {
                  console.log("Refund Charge Error", err);
                })
            }
          />

          <Text style={{marginVertical: 12}}>Cancels and Disconnects</Text>

          <Button
            title="Cancel Current Action"
            onPress={() =>
              cancelCurrentAction()
                .then((data) => {
                  console.log("Cancel Current Action", data);
                })
                .catch((err) => {
                  console.log("Cancel Current Action Error", err);
                })
            }
          />

          <Button
            title="Disconnect Reader"
            onPress={() =>
              disconnectReader()
                .then((data) => {
                  console.log("Disconnect Reader", data);
                })
                .catch((err) => {
                  console.log("Disconnect Reader Error", err);
                })
            }
          />

          <Text style={{marginVertical: 12}}>Status Buttons</Text>

          <Button
            title="Connected Reader"
            onPress={() =>
              getConnectedReader()
                .then((data) => {
                  console.log("Connected Reader", data);
                })
                .catch((err) => {
                  console.log("Connected Reader Error", err);
                })
            }
          />

          <Button
            title="Payment Intent"
            onPress={() =>
              getPaymentIntent()
                .then((data) => {
                  console.log("Payment Intent", data);
                })
                .catch((err) => {
                  console.log("Payment Intent Error", err);
                })
            }
          />

          <Button
            title="Payment Status"
            onPress={() =>
              getPaymentStatus()
                .then((data) => {
                  console.log("Payment Status", data);
                })
                .catch((err) => {
                  console.log("Payment Status Error", err);
                })
            }
          />

          <Button
            title="Connection Status"
            onPress={() =>
              getConnectionStatus()
                .then((data) => {
                  console.log("Connection Status", data);
                })
                .catch((err) => {
                  console.log("Connection Status Error", err);
                })
            }
          />
        </ScrollView>
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: "#F5FCFF",
  },
  welcome: {
    fontSize: 20,
    textAlign: "center",
    margin: 10,
    marginTop: 64,
  },
  instructions: {
    textAlign: "center",
    color: "#333333",
    marginBottom: 5,
  },
});
