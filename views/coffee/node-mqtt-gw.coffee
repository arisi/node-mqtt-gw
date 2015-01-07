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


source = new EventSource("/log.sse")
source.addEventListener "message", ((e) -> # note: 'newcontent'
  obj=$.parseJSON(e.data)
  if obj.type =="debug"
    $(".log").append obj.txt
    $(".log").scrollTop($("#loki")[0].scrollHeight);
  else
    console.log obj
    console.log "strange packet"
  return
), false
ajax
  send: "ident\n"
