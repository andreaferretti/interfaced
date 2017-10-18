import interfaced

import test_exports

type MyLogSink = object
    messages: seq[string]

proc log(this: var MyLogSink, msg: string) = this.messages.add(msg)
proc messagesWritten(this: MyLogSink): int = this.messages.len

when isMainModule:
    var myLogSink = MyLogSink(messages: @[])

    myLogSink.log("Hello World")
    myLogSink.log("ABC")
    
    echoSinkstate(myLogSink)