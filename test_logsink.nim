import interfaced

import test_exports

type MyLogSink = ref object
    messages: seq[string]

proc log(self: var MyLogSink, msg: string) = self.messages.add(msg)
proc messagesWritten(self: MyLogSink): int = self.messages.len

when isMainModule:
    var myLogSink = MyLogSink(messages: @[])

    myLogSink.log("Hello World")
    myLogSink.log("ABC")
    
    echoSinkstate(myLogSink.toLogSink)
    let i = myLogSink.toLogSink()
    myLogSink = nil
    GC_fullCollect()
    i.echoSinkState()