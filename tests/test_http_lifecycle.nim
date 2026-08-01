{.define: nimDisableCertificateValidation.}
{.define: ssl.}

import std/[net, os, strutils, times]
import windy/[common, http]

var
  httpCallbackCalled = false
  httpErrorMessage = ""
  webSocketCallbackCalled = false
  serverPort: Channel[int]
  responseQueued: Channel[bool]

proc serveTlsResponse() {.thread.} =
  let
    dataDir = currentSourcePath().parentDir / "data"
    context = newContext(
      verifyMode = CVerifyNone,
      certFile = dataDir / "http_test_cert.pem",
      keyFile = dataDir / "http_test_key.pem"
    )
    server = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  serverPort.send(server.getLocalAddr()[1].int)

  var client: owned(Socket)
  server.accept(client)
  context.wrapConnectedSocket(client, handshakeAsServer)
  while true:
    let line = client.recvLine()
    if line.strip().len == 0:
      break
  client.send(
    "HTTP/1.1 200 OK\c\L" &
      "Content-Length: 2\c\L" &
      "Connection: close\c\L\c\L" &
      "ok"
  )
  responseQueued.send(true)
  sleep(100)
  client.close()
  server.close()

serverPort.open()
responseQueued.open()
var serverThread: Thread[void]
createThread(serverThread, serveTlsResponse)

let request = startHttpRequest(
  "https://127.0.0.1:" & $serverPort.recv() & "/"
)
request.onResponse = proc(response: HttpResponse) =
  httpCallbackCalled = true
request.onError = proc(message: string) =
  httpCallbackCalled = true
  httpErrorMessage = message

let responseDeadline = epochTime() + 5.0
while responseQueued.peek() == 0:
  doAssert epochTime() < responseDeadline,
    "TLS response was not queued: " & httpErrorMessage
  pollHttp()
  sleep(1)
discard responseQueued.recv()
request.cancel()

let webSocket = openWebSocket("ws://127.0.0.1:1")
webSocket.onOpen = proc() =
  webSocketCallbackCalled = true
webSocket.onError = proc(message: string) =
  webSocketCallbackCalled = true
webSocket.close()

pollHttp()
pollHttp()

joinThread(serverThread)
responseQueued.close()
serverPort.close()

doAssert not httpCallbackCalled
doAssert not webSocketCallbackCalled
