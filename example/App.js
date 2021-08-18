/**
 * Sample React Native App
 *
 * adapted from App.js generated by the following command:
 *
 * react-native init example
 *
 * https://github.com/facebook/react-native
 */

import React, {Component} from 'react';
import {Button, StyleSheet, Text, View} from 'react-native';
import {
  cancelDiscoverReaders,
  collectPaymentMethod,
  connectBluetoothReader,
  createPaymentIntent, disconnectReader,
  discoverReaders,
  initialize,
  processPaymentIntent, readReusableCard, refundCharge,
  registerListener,
  retrievePaymentIntent,
} from 'react-native-stripe-terminal-v2';

export default class App extends Component<{}> {
  state = {
    status: 'starting',
    message: '--',
  };

  componentDidMount() {
    // if (Platform.OS === "android") {
    //   checkPermissions();
    // }
    this.setupReader();

    registerListener('readersDiscovered', readers => {
      if (readers.length > 0) {
        connectBluetoothReader(readers[0].serialNumber, "tml_DzDeZgFF76H5lT")
          .then(data => {
            console.log('WE DID IT MOM');
          })
          .catch(err => {
            console.log(err);
          });
      }

      console.log(readers);
    });
  }

  fetchConnectionToken() {
    let headers = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    };

    return new Promise(resolve => {
      fetch('https://api.dripdrinks.co/terminal/token', {
        method: 'POST',
        headers: headers,
      })
        .then(response => response.json())
        .then(responseJson => {
          if (responseJson['success']) {
            resolve(responseJson.data.secret);
          }
        });
    });
  }

  setupReader() {
    initialize({
      fetchConnectionToken: this.fetchConnectionToken.bind(this),
    })
      .then(err => {
        console.log('HERE2', err);
      })
      .catch(err => {
        console.log(err);
      });
  }

  render() {
    return (
      <View style={styles.container}>
        <Text style={styles.welcome}>
          ☆ReactNativeStripeTerminalV2 example☆
        </Text>
        <Button
          title="Discover Readers"
          onPress={() =>
            discoverReaders({
              simulated: false,
            })
              .then(data => {
                console.log(data);
              })
              .catch(err => {
                console.log(err);

                if (err.code === 'OH_CRICKY') {
                  cancelDiscoverReaders().then(() => {
                    console.log('WE CANCELLED');
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
              stripeDescription: 'test',
              metadata: {
                dog: "yes"
              }
            }).then(data => {
              console.log(data);
            })
          }
        />

        <Button
          title="Retreive Payment Intent"
          onPress={() =>
            retrievePaymentIntent(
              'pi_3JPqavAcqRxm04BK1XUXLQ89_secret_sQESXVyaebGPY5Cn6ZzUX8TFV',
            ).then(data => {
              console.log(data);
            })
          }
        />

        <Button
          title="Collect Payment Intent"
          onPress={() =>
            collectPaymentMethod().then(data => {
              console.log(data);
            })
          }
        />

        <Button
          title="Process Payment Intent"
          onPress={() =>
            processPaymentIntent()
              .then(data => {
                console.log(data);
              })
              .catch(err => {
                console.log('Process Payment Intent ERror', err);
              })
          }
        />

        <Button
          title="Read Reusable Card"
          onPress={() =>
            readReusableCard({metadata: {cats: "cool"}})
              .then(data => {
                console.log("YES DAD", data);
              })
              .catch(err => {
                console.log('Read Reusable Error', err);
              })
          }
        />

        <Button
          title="Refund Charge"
          onPress={() =>
            refundCharge("", 1000, {metadata: {cats: "cool"}})
              .then(data => {
                console.log("YES DAD", data);
              })
              .catch(err => {
                console.log('Read Reusable Error', err);
              })
          }
        />

        <Button
          title="Disconnect Reader"
          onPress={() =>
            disconnectReader()
              .then(data => {
                console.log("YES DAD", data);
              })
              .catch(err => {
                console.log('Disconenct Error', err);
              })
          }
        />
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  instructions: {
    textAlign: 'center',
    color: '#333333',
    marginBottom: 5,
  },
});