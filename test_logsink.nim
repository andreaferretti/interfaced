import interfaced

import test_exports

type MyLogSink = object
    messages: seq[string]

proc log(self: var MyLogSink, msg: string) = self.messages.add(msg)
proc messagesWritten(self: MyLogSink): int = self.messages.len

when isMainModule:
    var myLogSink = MyLogSink(messages: @[])

    myLogSink.log("Hello World")
    myLogSink.log("ABC")
    
    echoSinkstate(myLogSink)