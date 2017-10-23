## Go-Like Interfaces for Nim
##
## Example:
## ========
## You can find more examples in the files ``test.nim``, ``test_logsink.nim`` and ``test_exports.nim``.
##
## .. code-block:: nim
##   # interface definition:
##   createInterface LogSink:
##     proc log(this: LogSink, msg: string)
##     proc messagesWritten(this: LogSink): int
##   
##   # interface implementation
##   type MyLogSink = object
##     messages: seq[string]
##   
##   proc log(this: var MyLogSink, msg: string) = this.messages.add(msg)
##   proc messagesWritten(this: MyLogSink): int = this.messages.len
##
##   # ...
##   
##   # the order of definition and implementation doesn't matter, as long both are defined at the point where the conversion happens
##   
##   var myLogSink = MyLogSink()
##   
##   let
##     logSinkA = myLogSink.toLogSink() # explicit conversion
##     logSinkB: LogSink = myLogSink # implicit conversion
##   
##   logSinkA.log("Hello World")
##   logSinkB.log("Bye World")
##
import macros

proc exportIdent(ident: NimNode, exports: bool): NimNode {.compileTime.} =
  if exports: nnkPostfix.newTree(newIdentNode("*"), ident) else: ident

macro implementInterface(interfaceName: typed, exports: static[bool]) : untyped =
  let
    interfaceNameStr = $interfaceName.symbol
    vtableSymbol = interfaceName.symbol.getImpl[2][2][1][1][0]
    vtableRecordList = vtableSymbol.symbol.getImpl[2][2]

  let
    objectConstructor = nnkObjConstr.newTree(vtableSymbol)
  
  for identDefs in vtableRecordList:
    let
      methodName = identDefs[0]
      params = identDefs[1][0]
      thisParameter = params[1][0]

      testThis = newIdentNode("x")
      lambdaBody = quote do:
        `methodName`(cast[T](`thisParameter`))

      recursiveTest = quote do:
        `methodName`(`testThis`)
      
    for i in 2 ..< len(params):
      let param = params[i]
      param.expectKind(nnkIdentDefs)
      for j in 0 .. len(param) - 3:
        lambdaBody.add param[j]
        recursiveTest.add param[j]

    methodName.expectKind nnkIdent

    let recursiveCheck = quote do:
      var `testThis` = T(nil)
      when not(compiles(`recursiveTest`)):
        {.fatal: "recursive call".}

    objectConstructor.add nnkExprColonExpr.newTree(
      methodName,
      nnkLambda.newTree(
        newEmptyNode(),newEmptyNode(),newEmptyNode(),
        params.copy,
        newEmptyNode(),newEmptyNode(),
        newStmtList(
          nnkMixinStmt.newTree(methodName),
          recursiveCheck,
          lambdaBody
        )
      )
    )

  let
    getVtableReturnStatement =
      nnkReturnStmt.newTree(newCall("addr", newIdentNode("theVtable")))
    globalVtableIdent = newIdentNode("theVtable")
    getVtableProcIdent = newIdentNode("get" & interfaceNameStr & "Vtable")
    vtableType = newIdentNode(interfaceNameStr & "Vtable")
    getVtableProcDeclaration = quote do:
      proc `getVtableProcIdent`[T](): ptr `vtableType` =
        var `globalVtableIdent` {.global.} = `objectConstructor`
        `getVtableReturnStatement`

  result = newStmtList()
  result.add getVtableProcDeclaration

  let 
    castIdent = exportIdent(newIdentNode("to" & $interfaceName.symbol), exports)
  result.add quote do:
    proc `castIdent`(this: ref) : `interfaceName` = 
      `interfaceName`(
        objet : cast[RootRef](this),
        vtable : `getVtableProcIdent`[type(this)]()
      )

  when defined(interfacedebug):
    echo result.repr

macro createInterface*(name : untyped, methods : untyped) : untyped =
  ## Creates an interface named ``name``. By putting an asterix ``*`` before ``name``, the interface type will be exported. 
  ## Methods need to be exported individually(see ``test_exports.nim``. 
  ##
  ## Even if a method isn't *callable* from the current scope, it's possible to implement it(see ``test_logsinks.nim``). In the 
  ## same way an implementation may follow the interface definition it is implementing or an unexported procedure can implement an exported method, 
  ## as long it's visible at the point of the conversion.
  if name.kind != nnkPrefix: name.expectKind nnkIdent

  let
    exports = name.kind == nnkPrefix
    cleanedName = if exports: name[1] else: name    
    nameStr = $cleanedName.ident
    markedName = if exports: newTree(nnkPostfix, newIdentNode("*"), cleanedName) else: name  

    vtableRecordList = nnkRecList.newTree
    vtableIdent = newIdentNode(nameStr & "Vtable")
    vtableTypeDef = nnkTypeSection.newTree(
      nnkTypeDef.newTree(
        vtableIdent,
        newEmptyNode(),
        nnkObjectTy.newTree(
          newEmptyNode(),
          newEmptyNode(),
          vtableRecordList
        )
      )
    )

  var newMethods = newSeq[NimNode]()

  for meth in methods:
    meth.expectKind(nnkProcDef)
    let
      methodIdent = if meth[0].kind == nnkPostfix: meth[0][1] else: meth[0]
      params = meth[3]
      thisParam = params[1]
      thisIdent = thisParam[0]
      thisType  = thisParam[1]

    if thisType != cleanedName:
      error thisType.repr & " != " & cleanedName.repr

    let vtableEntryParams = params.copy
    vtableEntryParams[1][1] = newIdentNode("RootRef")

    vtableRecordList.add(
      nnkIdentDefs.newTree(
        methodIdent,
        nnkProcTy.newTree(
          vtableEntryParams,
          newEmptyNode(),
        ),
        newEmptyNode()
      )
    )

    let call = nnkCall.newTree(
      nnkDotExpr.newTree( nnkDotExpr.newTree(thisIdent, newIdentNode("vtable")), methodIdent  ),
      nnkDotExpr.newTree( thisIdent, newIdentNode("objet") ),
    )

    for i in 2 ..< len(params):
      let param = params[i]
      param.expectKind(nnkIdentDefs)
      for j in 0 .. len(param) - 3:
        call.add param[j]

    meth[6] = nnkStmtList.newTree(call)

    newMethods.add(meth)

  result = newStmtList()
  result.add(vtableTypeDef)
  result.add quote do:
    type `markedName` = object
      objet : RootRef
      vtable: ptr `vtableIdent`

  for meth in newMethods:
    result.add meth

  result.add newCall(bindSym"implementInterface", cleanedName, newIdentNode(if exports: "true" else: "false"))

  when defined(interfacedebug):
    echo result.repr
