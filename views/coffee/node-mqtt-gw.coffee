term=null
pause=false
stamp = () ->
  (new Date).getTime();

ajax_data = (data) ->
  console.log "ajax:",data
  $(".adata").html(data.now)

@ajax = (obj) ->
  console.log "doin ajax"
  $.ajax
    url: "/ajax"
    type: "GET"
    dataType: "json",
    contentType: "application/json; charset=utf-8",
    data: obj
    success: (data) ->
      ajax_data(data)
      return
    error: (xhr, ajaxOptions, thrownError) ->
      alert thrownError
      return

delta = (s) ->
  if s
    ((stamp()-s)/1000).toFixed(1)
  else
    ""
buf=""

buf2term = () ->
  while true
    p=buf.indexOf("\n")
    if p!=-1
      term.echo "[[b;yellow;black]#{buf[0..p-1]}]"
      buf=buf[p+1..-1]
    else
      break

sse_data = (obj) ->
  if obj.type =="plist_all"
    html="<table>"
    html+="<tr>"
    html+="<th>port</th>"
    html+="<th>serno</th>"
    html+="<th>state</th>"
    html+="<th>lastp3</th>"
    html+="<th>stamp</th>"
    html+="<th>exist</th>"
    html+="<tr>"
    for dev,data of obj.data
      html+="<tr>"
      html+="<td>#{dev}</td>"
      html+="<td>#{data.id}</td>"
      html+="<td>#{data.state}</td>"
      html+="<td>#{delta(data.lastp3)}</td>"
      html+="<td>#{delta(data.stamp)}</td>"
      html+="<td>#{delta(data.exist)}</td>"
      html+="</td>"
      html+="</tr>"
    html+="</table>"
    console.log obj
    $("#devs").html html
  else if obj.type =="debug"
    #$(".log").append obj.txt
    #$(".log").scrollTop($("#loki")[0].scrollHeight);
    #term.echo "[[raw]#{obj.txt}]"
    buf+=obj.txt
    if not pause
      buf2term()
  else
    console.log obj
    console.log "strange packet"


jQuery ($, undefined_) ->

  source = new EventSource("/log.sse")
  source.addEventListener "message", ((e) -> # note: 'newcontent'
    obj=$.parseJSON(e.data)
    sse_data obj
    return
  ), false
  ajax
    send: "\nauth 1682\n"

  term=$("#term").terminal ((command, term) ->
    if command isnt ""
      try
        if command=="rs"
          command="rbuf stat"
        else if command=="ds"
          command="devs stat"
        else if command=="ps"
          command="tasks stat"
        if command=="cls"
          term.clear()
        else if command=="pause"
          pause=not pause
          if pause
            term.echo "paused!"
          else
            term.echo "unpaused!"
            buf2term()
        else
          ajax
            send: "#{command}\n"
        #term.echo new String(result)  if result isnt `undefined`
      catch e
        term.error new String(e)
    else
      term.echo ""
    return
  ),
    greetings: "Tikkuterminaali!"
    name: "tikku"
    height: 600
    width: 800
    prompt: "] "
  chrome.bluetooth.getDevices (a,b)->
    console.log a,b

