
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

source = new EventSource("/log.sse")
source.addEventListener "message", ((e) -> # note: 'newcontent'
  obj=$.parseJSON(e.data)
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
    $(".log").append obj.txt
    $(".log").scrollTop($("#loki")[0].scrollHeight);
  else
    console.log obj
    console.log "strange packet"
  return
), false
ajax
  send: "ident\n"
