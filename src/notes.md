```sh
# INTERESTING: Working cleanup in shims rather than Nim code
# proc registerCleanup*(el: Node, fn: Unsub)
#   {.importjs: "((e,f)=>{(e.__nimbusC||(e.__nimbusC=[])).push(f)})(#,#)".}
# proc runCleanups*(el: Node)
#   {.importjs: "((e)=>{if(e.__nimbusC){for(var i=0;i<e.__nimbusC.length;i++){try{e.__nimbusC[i]();}catch(_){}} e.__nimbusC=[]}})(#)".}
```
