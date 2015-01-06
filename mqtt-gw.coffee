console.log "node-mqtt-gw:"

plist={}
plistp={}
sse_list={}
sse_sc=1 #sessio counter
serialport = require("serialport")
SerialPort = serialport.SerialPort

http = require("http")
express = require("express")
fs = require('fs');
hamlc = require 'haml-coffee'
cs = require 'coffee-script'

app = express()

console.log "workdir:",__dirname

app.get "/js/:page.js", (req, res) ->
  res.set('Content-Type', 'application/javascript');
  cof = fs.readFileSync "views/coffee/#{req.params.page}.coffee", "ascii"
  res.send cs.compile cof

app.get "/css/:page.css", (req, res) ->
  res.set('Content-Type', 'text/css');
  cof = fs.readFileSync "views/css/#{req.params.page}.css", "ascii"
  res.send cof

app.get "/:page.json", (req, res) ->
  console.log "json",req.query,"params:",req.params
  res.json plist

app.get "/:page.sse", (req, res) ->
  #console.log "sse",req.query,"params:",req.params
  req.socket.setTimeout(Infinity);
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive'
  });
  res.write('\n');
  res.write "ok\n\n"
  messageCount = 0
  ses=sse_sc
  res.write('id: ' + messageCount + '\n');
  res.write("data: " + JSON.stringify({type: "init",ses: ses}) + '\n\n');
  messageCount++

  sse_sc+=1
  sse_list[ses]= (obj) ->
    messageCount++
    res.write('id: ' + messageCount + '\n');
    res.write("data: " + JSON.stringify(obj) + '\n\n');
  plist2sse ses #send current state of ports to this new session

  req.on "close", () ->
    console.log "sse #{ses} closed"
    delete sse_list[ses]


app.get "/:page", (req, res) ->
  console.log "doin haml:",req.query,"params:",req.params
  data={title: "jees"}
  ham = fs.readFileSync "views/index.haml", "ascii"
  comp= hamlc.compile ham
  str= comp plist: plist
  console.log str
  res.send str
  console.log "did haml "

app.listen 3000

sse_out = (obj) ->
  console.log "sse_out #{obj.type} ->",sse_list
  for ses,sse of sse_list
    sse obj

addport = (p) ->
  if not plist[p] or plist[p].state=="closed"
    plist[p]={state: "init",p3: false, p3esc: false,p3buf: []}
    plistp[p]={}

P3_START='~'.charCodeAt(0)
P3_END='^'.charCodeAt(0)
P3_ESC='#'.charCodeAt(0)

p3_inchar = (p,ch) ->
  if ch==P3_START and not plist[p].p3esc and not plist[p].p3
    plist[p].p3=true
    plist[p].p3buf=[]
    return true
  else if ch==P3_END and not plist[p].p3esc and plist[p].p3
    sse_out
      "type": "s3"
      "port": p
      "s3": plist[p].p3buf
    plist[p].p3=false
    return true
  else
    if not plist[p].p3
      return false
    else
      if plist[p].p3esc
        plist[p].p3esc=false
      else if ch==P3_ESC
        plist[p].p3esc=true
        return true
      plist[p].p3buf.push ch
  return true

initport = (p) ->
  myPort = new SerialPort(p,
    baudRate: 115200
    dataBits: 8
    parity: 'none'
    stopBits: 1
    flowControl: false
    #parser: serialport.parsers.readline("\n")
  ,false)
  myPort.open (error) ->
    if error
      console.log "ei aukea ",p
    else
      console.log "aukes",p
      plist[p].state="open"
      plistp[p].port=myPort

      myPort.on "data", (data) ->
        console.log "#{p}: #{data}"
        dbuf=""
        for ch in data
          if not p3_inchar(p,ch)
            dbuf+=String.fromCharCode ch
          #console.log ":",ch,":",String.fromCharCode ch
        if dbuf!=""
          sse_out
            "type": "debug"
            "port": p
            "txt": "#{dbuf}"

      myPort.on "close", (error) ->
        console.log "port closed: #{p} " + error
        plist[p].state="closed"
        return

      myPort.write "ident\n", (err, results) ->
        if err
          console.log "err " + err
        console.log "results <" + results+">"
        return

old_plist={}

plist2sse = (ses) ->
  if ses>0
    for p,obj of plist
      sse_out
        "type": "plist"
        "port": p
        "state": plist[p].state
  else
    for p,obj of plist
      if not old_plist[p] or old_plist[p].state!=plist[p].state
        ostate="?"
        if old_plist[p]
          ostate= old_plist[p].state
        else
          old_plist[p]={}
        sse_out
          "type": "plist"
          "port": p
          "ostate": ostate
          "state": plist[p].state
        old_plist[p].state=plist[p].state


scanports = () ->
  #this needed for linux, as .list does not seem to pick up all serial ports
  files=fs.readdirSync "/dev"
  pat = new RegExp(/^tty(ACM|USB).+$/);
  for f in files
    if f.match pat
      p="/dev/#{f}"
      addport p

  serialport.list (err, ports) ->
    for port in ports
      if port
        addport port.comName
  plist2sse(0)
  for p,obj of plist
    if obj.state =="init"
      console.log "initing",p
      initport p

setInterval (->
  scanports()
  return
), 10

options =
  host: "www.google.com"
  port: 80
  path: "/index.html"

if false
  http.get(options, (res) ->
    console.log "Got response: " + res.statusCode
    return
  ).on "error", (e) ->
    console.log "Got error: " + e.message
    return

exitHandler = (options, err) ->
  if options.cleanup
    console.log "\nclean"
    sse_out
      "type": "sys"
      "msg": "shutdown"
  console.log err.stack  if err
  process.exit()  if options.exit
  return
process.stdin.resume()

#do something when app is closing
process.on "exit", exitHandler.bind(null,
  cleanup: true
)

#catches ctrl+c event
process.on "SIGINT", exitHandler.bind(null,
  exit: true
)

#catches uncaught exceptions
process.on "uncaughtException", exitHandler.bind(null,
  exit: true
)
