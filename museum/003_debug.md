# Debug mode

I found that this is an interesting way to debug, by passing a custom flag to the compiler such as
`nim js -d:loopDebug ntml.nim`. You can see I was using this when implementing macro lowering
for iterators.

```nim
when defined(loopDebug):
  echo "=== LOWERED FOR ==="
  echo treeRepr(newTree(nnkStmtList,
    renderProc,
    newCall(ident"mountFor", parent, newCall(ident"toSeqAuto", iterExpr), renderFn)
  ))
```
