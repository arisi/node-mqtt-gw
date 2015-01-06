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
