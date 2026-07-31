import windy/[common, http]

var
  httpCallbackCalled = false
  webSocketCallbackCalled = false

let request = startHttpRequest("http://127.0.0.1:1")
request.onResponse = proc(response: HttpResponse) =
  httpCallbackCalled = true
request.onError = proc(message: string) =
  httpCallbackCalled = true
request.cancel()

let webSocket = openWebSocket("ws://127.0.0.1:1")
webSocket.onOpen = proc() =
  webSocketCallbackCalled = true
webSocket.onError = proc(message: string) =
  webSocketCallbackCalled = true
webSocket.close()

pollHttp()
pollHttp()

doAssert not httpCallbackCalled
doAssert not webSocketCallbackCalled
