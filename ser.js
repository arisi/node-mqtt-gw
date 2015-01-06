#!/usr/bin/env node

console.log ("node-mqtt-gw:");

var serialport = require("serialport");

var express = require('express')
var cons = require('consolidate');
var app = express()
console.log(__dirname);
cons.haml(__dirname+'/views/index.haml', { user: 'tobi' }, function(err, html){
  if (err) throw err;
  console.log(html);
});

app.get('/', function (req, res) {
  res.send('Hello World')
})

app.get('/ports', function (req, res) {
  serialport.list(function (err, ports) {
      s="portit: ";
      ports.forEach(function(port) {
        console.log(port.comName);
        s+=port.comName+",";
      });
      res.send(s)
    });

})

app.listen(3000)

portName = process.argv[2];
if (portName=="" || portName==undefined) {
    console.log("Available ports:");
    serialport.list(function (err, ports) {
      ports.forEach(function(port) {
        console.log(port.comName);
      });
    });
    return;
}
SerialPort = serialport.SerialPort // make a local instance of it


var myPort = new SerialPort(portName, {
   baudRate: 115200,
   parser: serialport.parsers.readline("\n")
 });

function showPortOpen() {
  console.log('port open. Data rate: ' + myPort.options.baudRate);
  myPort.write("ident\n");
}

function saveLatestData(data) {
   console.log(data);
}

function showPortClose() {
   console.log('port closed.');
}

function showError(error) {
   console.log('Serial port error: ' + error);
}

myPort.on('open', showPortOpen);
myPort.on('data', saveLatestData);
myPort.on('close', showPortClose);
myPort.on('error', showError);

