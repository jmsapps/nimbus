type
  Unsub* = proc ()

  Subscriber*[T] = proc (v: T)

  Signal*[T] = ref object
    value*: T
    subs*: seq[Subscriber[T]]

  Props* = object of RootObj
    accesskey*: string = ""        #	Keyboard shortcut to activate/focus an element
    autocapitalize*: string = ""   #	Controls text capitalization in forms (none, sentences, etc.)
    autofocus*: string = ""        #	Automatically focus element when page loads
    class*: string = ""            #	CSS class list
    contenteditable*: string = ""  #	Makes element’s content editable
    dir*: string = ""              #	Text direction (ltr, rtl, auto)
    draggable*: string = ""        #	Whether element can be dragged (true / false)
    enterkeyhint*: string = ""     #	Suggests enter key label on virtual keyboards
    hidden*: string = ""           #	Hides the element
    id*: string = ""               #	Unique element identifier
    inert*: string = ""            #	Prevents interaction/focus (newer browsers)
    inputmode*: string = ""        #	Virtual keyboard type (numeric, email, etc.)
    `is`*: string = ""             # Used for customized built-in elements
    itemid*: string = ""           # Microdata attribute
    itemprop*: string = ""         # Microdata attribute
    itemref*: string = ""          # Microdata attribute
    itemscope*: string = ""        # Microdata attribute
    itemtype*: string = ""         # Microdata attribute
    lang*: string = ""             #	Language of element content
    nonce*: string = ""            #	CSP nonce for inline scripts/styles
    part*: string = ""             # Shadow DOM parts
    popover*: string = ""          #	Popover behavior (manual, auto)
    slot*: string = ""             # Slot name for Web Components
    spellcheck*: string = ""       # Enable/disable spell checking
    style*: string = ""            #	Inline CSS styles
    tabindex*: string = ""         #	Tab order for focus
    title*: string = ""            #	Tooltip / advisory text
    translate*: string = ""        #	Whether to translate the element’s text (yes / no)
