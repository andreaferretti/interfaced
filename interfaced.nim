import macros

macro implementInterface(interfaceName: typed) : untyped =
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
      lambdaBody = quote do:
        cast[var T](this).`methodName`()
      call = lambdaBody[0]

    for i in 2 ..< len(params):
      let param = params[i]
      param.expectKind(nnkIdentDefs)
      for j in 0 .. len(param) - 3:
        call.add param[j]

    # leave out () when not needed
    if call.len == 1:
      lambdaBody[0] = call[0]

    methodName.expectKind nnkIdent

    objectConstructor.add nnkExprColonExpr.newTree(
      methodName,
      nnkLambda.newTree(
        newEmptyNode(),newEmptyNode(),newEmptyNode(),
        params.copy,
        newEmptyNode(),newEmptyNode(),
        lambdaBody
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

  let castIdent = newIdentNode("to" & $interfaceName.symbol)

  result.add quote do:
    converter `castIdent`[T](this: ptr T) : `interfaceName` = `interfaceName`(
      objet : this,
      vtable : `getVtableProcIdent`[T]()
    )

  result.add quote do:
    converter `castIdent`[T](this: var T) : `interfaceName` = `interfaceName`(
      objet : this.addr,
      vtable : `getVtableProcIdent`[T]()
    )

  result.add quote do:
    converter `castIdent`(this: `interfaceName`): `interfaceName` = this

  when defined(interfacedebug):
    echo result.repr


macro createInterface*(name : untyped, methods : untyped) : untyped =
  name.expectKind nnkIdent


  let
    nameStr = $name.ident
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
      methodIdent = meth[0]
      params = meth[3]
      thisParam = params[1]
      thisIdent = thisParam[0]
      thisType  = thisParam[1]

    if thisType != name:
      error thisType.repr & " != " & name.repr

    let vtableEntryParams = params.copy
    vtableEntryParams[1][1] = newIdentNode("pointer")

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
    type `name` = object
      objet : pointer
      vtable: ptr `vtableIdent`

  for meth in newMethods:
    result.add meth

  result.add newCall(bindSym"implementInterface", name)

  when defined(interfacedebug):
    echo result.repr