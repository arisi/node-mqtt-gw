console.log "node-mqtt-gw:::"

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
printf = require('printf');
dgram = require('dgram');
sprintf = require('sprintf').sprintf;
yaml = require('js-yaml');

getUserHome = () ->
  process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE;

console.log "HOME:",getUserHome()

options={jee: ["joo","jyy",123]}

cfile="#{getUserHome()}/node-mqtt-gw.yaml"
console.log "cfile:",cfile
try
  options = yaml.safeLoad(fs.readFileSync(cfile, 'utf8'));
  console.log options;
catch e
  console.log(e);
  console.log "no config!"

data=yaml.dump(options)
console.log "->",data

fs.writeFile cfile, data, "utf-8", () ->
  console.log "wrote ok",data

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
  res.write("data: " + JSON.stringify({type: "init",ses: ses,options: options}) + '\n\n');
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

app.get ["/ajax"], (req, res) ->
  console.log "ajax:",req.query,"params:",req.params
  for p,dev of plistp
    console.log "dev:",p,dev
    if dev.port
      dev.port.write "#{req.query.send}\n"
  res.json plist

app.get ["/:page.html","/:page.htm","/"], (req, res) ->
  console.log "doin haml:",req.query,"params:",req.params
  comp= hamlc.compile fs.readFileSync "views/index.haml", "ascii"
  str= comp
    plist: plist
  res.send str

app.use (req, res) ->
  console.log "def:",req

  path=req._parsedUrl.pathname
  if (fs.existsSync("views/#{path}"))
    cof = fs.readFileSync "views/#{path}", "ascii"
    res.send cof
  else
    res.send(404);


app.listen 3000

stamp = () ->
  (new Date).getTime();

sse_out = (obj) ->
  #console.log "sse_out #{obj.type} ->",sse_list
  for ses,sse of sse_list
    sse obj

addport = (p) ->
  if not plist[p] or plist[p].state=="closed"
    zap p
    plist[p]={state: "init",p3: false, p3esc: false,p3buf: [],stamp: 0, id:"" }
    plistp[p]={}
  plist[p].exist=stamp()

P3_START='~'.charCodeAt(0)
P3_END='^'.charCodeAt(0)
P3_ESC='#'.charCodeAt(0)


clients={}

p3_outpac = (p,pac) ->
  console.log "p3_outpac",p,pac
  if plistp[p].port

    buf=[]
    buf.push pac["proto"].charCodeAt(0)

    macs=pac["mac"].split(":")
    buf.push parseInt(macs[0],16)
    buf.push parseInt(macs[1],16)
    buf.push 0
    buf.push 0

    ips=pac["ip"].split(".")
    buf.push parseInt(ips[3])
    buf.push parseInt(ips[2])
    buf.push parseInt(ips[1])
    buf.push parseInt(ips[0])

    buf.push (pac["port"]&0xff)
    buf.push pac["port"]/0x100
    buf.push pac["data"].length
    for ch in pac["data"].split("")
      buf.push ch.charCodeAt(0)
    check=0
    for b in buf
      check^=b
    buf.push check
    buf.unshift P3_START
    buf.push P3_END
    console.log buf
    #pp buf
    #pp "#{P3_START.chr}#{buf.pack("C*")}#{P3_END.chr}"

    plistp[p].port.write buf


p3_inpac = (p,pac) ->
  plist[p].lastp3=stamp()
  if pac[0]=="P".charCodeAt(0)
    id=""
    for ch in pac[12..-2]
      id+=String.fromCharCode ch
    console.log "PINGI!!!! len=#{pac[11]} '#{id}'"
    if plist[p].id==""
      plist[p].id=id
      sse_out
        "type": "plist"
        "port": p
        "data": plist[p]

    else plist[p].id!=id
      #conflict -- serial number has changed?
    p3_outpac p,
      proto: "P"
      mac: "00:00"
      ip: "0.0.0.0"
      port: 0
      data: "PONG"

  else if pac[0]=="U".charCodeAt(0)
    mac=sprintf "%02X:%02X",pac[2],pac[1]
    ip=sprintf "%d.%d.%d.%d",pac[8],pac[7],pac[6],pac[5]
    port=pac[9]+pac[10]*0x100
    console.log "UDP!!!! len=#{pac[11]} mac=#{mac} ip=#{ip} port=#{port}"
    if not plistp[p].udp
      plistp[p].udp=dgram.createSocket('udp4');
      plistp[p].udp.on 'listening', () ->
        address = plistp[p].udp.address();
        console.log 'UDP Server listening on ' + address.address + ":" + address.port
      plistp[p].udp.on 'message', (message, remote) ->
        console.log "msg:",message.toString()
    message = new Buffer(pac[12..-2]);
    plistp[p].udp.send message, 0, message.length, port, ip, (err, bytes) ->
      if (err)
        throw err;
      console.log('UDP message sent');

  sse_out
    "type": "s3"
    "port": p
    "s3": pac

p3_inchar = (p,ch) ->
  if not plist[p]
    return false

  if ch==P3_START and not plist[p].p3esc and not plist[p].p3
    plist[p].p3=true
    plist[p].p3buf=[]
    return true
  else if ch==P3_END and not plist[p].p3esc and plist[p].p3
    p3_inpac p, plist[p].p3buf
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
  plist[p].state="initing"
  plist[p].stamp=stamp()
  myPort = new SerialPort(p,
    baudRate: 115200
    dataBits: 8
    parity: 'none'
    stopBits: 1
    flowControl: false
  ,false)
  myPort.open (error) ->
    if error
      console.log "Error: Cannot Open ",p
      plist[p].state="failed"
      plist[p].stamp=stamp()
    else
      plist[p].state="open"
      plist[p].stamp=stamp()
      plistp[p].port=myPort

      myPort.on "data", (data) ->
        dbuf=""
        for ch in data
          if not p3_inchar(p,ch)
            dbuf+=String.fromCharCode ch
        if dbuf!=""
          sse_out
            "type": "debug"
            "port": p
            "txt": "#{dbuf}"

      myPort.on "close", (error) ->
        console.log "port closed: #{p} " + error
        zap p
        return

      myPort.write "ident\n", (err, results) ->
        if err
          console.log "err " + err
        return

old_plist={}

plist2sse = (ses) ->
  if ses>0
    sse_out
      "type": "plist_all"
      "data": plist
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
          "data": plist[p]
        old_plist[p].state=plist[p].state

zap = (p) ->
  if plist[p]
    delete plist[p]
  if plistp[p]
    if plistp[p].udp
      plistp[p].udp.close
    if plistp[p].port
      plistp[p].port.close
    delete plistp[p]


scanports = () ->
  #this needed for linux, as .list does not seem to pick up all serial ports
  if (fs.existsSync("/dev"))
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
    if obj.state == "open" and obj.exist < (stamp() - 10000) #lost port
      console.log "stale port #{p}"
      zap p
      console.log plist
    if obj.state == "open" and obj.lastp3 < (stamp() - 10000) #lost port
      console.log "stale p3 port #{p}"
      zap p
      console.log plist
    if obj.state != "open" and obj.stamp < (stamp() - 2000) and obj.exist > (stamp() - 5000)
      if plist[p].state=="initing" and obj.stamp > (stamp() - 10000)
        return
      console.log "initing",p
      initport p
      #console.log plist

scanports()

setInterval (->
  scanports()
  return
), 1000

setInterval (->
  plist2sse(1)
  return
), 1000



if false
  woptions =
    host: "www.google.com"
    port: 80
    path: "/index.html"

  http.get(woptions, (res) ->
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
