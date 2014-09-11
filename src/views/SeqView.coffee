view = require("../bone/view")
dom = require("../utils/dom")
svg = require("../utils/svg")
_ = require "underscore"
jbone = require "jbone"

# displays the residues
SeqView = view.extend

  initialize: (data) ->
    @g = data.g
    @_build()

    # setup listeners
    @listenTo @model, "change:grey", @_build
    @listenTo @g.columns, "change:hidden", @_build
    @listenTo @model, "change:features", @_build
    @listenTo @g.selcol, "add", (sel, b) ->
      if @g.selcol.getSelForRow(@model.get('id')).length isnt 0
        @_appendSelection()
    @listenTo @g.selcol, "reset", @_build
    @listenTo @g.zoomer, "change", @_build
    @listenTo @g.colorscheme,"change", ->
      @_build()
      @render()
    @manageEvents()

  manageEvents: ->
    events = {}
    if @g.config.get "registerMouseClicks"
      events.click = "_onclick"
    if @g.config.get "registerMouseHover"
      events.mousein = "_onmousein"
      events.mouseout = "_onmouseout"
    @delegateEvents events
    @listenTo @g.config, "change:registerMouseHover", @manageEvents
    @listenTo @g.config, "change:registerMouseClick", @manageEvents

  _build: ->
    dom.removeAllChilds @el

    seq = @model.get("seq")
    hidden = @g.columns.get "hidden"
    textVisible = @g.zoomer.get "textVisible"
    features = @model.get "features"
    cellHeight = @g.zoomer.get "rowHeight"
    cellWidth = @g.zoomer.get "columnWidth"
    hiddenOffset = 0

    for n in [0..seq.length - 1] by 1
      if hidden.indexOf(n) < 0
        span = document.createElement "span"
        span.rowPos = n
        if textVisible
          span.textContent = seq[n]
        else
          # setting the height is faster than dummy whitespace
          span.style.height = cellHeight

        starts = features.startOn n
        if starts.length > 0
          for f in starts
            span.appendChild @appendFeature f


        @_drawResidue span, seq[n],n
        span.style.width = cellWidth
        span.style.position = "relative"
        @el.appendChild span

    @_appendSelection()

  _appendSelection: ->
    seq = @model.get("seq")
    selection = @_getSelection @model
    hidden = @g.columns.get "hidden"
    # get the status of the upper and lower row
    [mPrevSel,mNextSel] = @_getPrevNextSelection()

    childs = @el.children

    # avoid unnecessary loops
    return if selection.length is 0

    hiddenOffset = 0
    for n in [0..seq.length - 1] by 1
      if hidden.indexOf(n) >= 0
        hiddenOffset++
      else
        k = n - hiddenOffset
        if childs[k]?
          if childs[k].children.length > 0
            # remove old selections
            for child in childs[k].children
              if child.type is "selection"
                childs[k].removeChild child
          # only if its a new selection
          if selection.indexOf(n) >= 0 and (k is 0 or selection.indexOf(n - 1) < 0 )
            childs[k].appendChild @_renderSelection n,selection,mPrevSel,mNextSel

  render: ->
    @el.style.height = @g.zoomer.get "rowHeight"
    @el.className = "biojs_msa_seqblock"

    if @g.colorscheme.get "colorBackground"
      @el.className += " biojs-msa-schemes-" + @g.colorscheme.get "scheme"
    else
      @el.className += " biojs-msa-schemes-" + @g.colorscheme.get("scheme") +
      "-bl"

  # TODO: remove this boilerplate code for events
  _onclick: (evt) ->
    seqId = @model.get "id"
    @g.trigger "residue:click", {seqId:seqId, rowPos: evt.target.rowPos, evt:evt}

  _onmousein: (evt) ->
    seqId = @model.get "id"
    evt.seqId = seqId
    @g.trigger "residue:mousein", {seqId:seqId, rowPos: evt.target.rowPos, evt:evt}

  _onmouseout: (evt) ->
    seqId = @model.get "id"
    evt.seqId = seqId
    @g.trigger "residue:mousein", {seqId:seqId, rowPos: evt.target.rowPos, evt:evt}

  # sets the properties of a single residue
  _drawResidue: (span,residue,index) ->
    if @g.colorscheme.get('scheme') is "pid"
      cons = @g.columns.get('conserv')[index]
      if cons > 0.80
        span.style.backgroundColor = "#6464ff"
      else if 0.60 < cons <= 0.80
        span.style.backgroundColor = "#9da5ff"
      else if 0.40 < cons <= 0.60
        span.style.backgroundColor = "#cccccc"
    else
      unless @model.get("grey").indexOf(index) >= 0
        span.className = "biojs-msa-aa-" + residue

  # TODO: should I be moved to the selection manager?
  # returns an array with the currently selected residues
  # e.g. [0,3] = pos 0 and 3 are selected
  _getSelection: (model) ->
    maxLen = model.get("seq").length
    selection = []
    sels = @g.selcol.getSelForRow model.get "id"
    rows = _.find sels, (el) -> el.get("type") is "row"
    if rows?
      # full match
      for n in [0..maxLen - 1] by 1
        selection.push n
    else if sels.length > 0
      for sel in sels
        for n in [sel.get("xStart")..sel.get("xEnd")] by 1
          selection.push n

    return selection

  _getPrevNextSelection: ->
    # looks at the selection of the prev and next el
    # TODO: this is very naive, as there might be gaps above or below
    modelPrev = @model.collection.prev @model
    modelNext = @model.collection.next @model
    mPrevSel = @_getSelection modelPrev if modelPrev?
    mNextSel = @_getSelection modelNext if modelNext?
    [mPrevSel,mNextSel]

  # displays the current user selection
  # and checks the prev and next row for selection  -> no borders in a selection
  _renderSelection: (n, selection, mPrevSel, mNextSel) ->

    # get the length of this selection
    selectionLength = 0
    for i in [n.. @model.get("seq").length - 1] by 1

      if selection.indexOf(i) >= 0
        selectionLength++
      else
        break

    # TODO: ugly!
    width = @g.zoomer.get("columnWidth")
    totalWidth = (width * selectionLength) + 1
    cHeight = @g.zoomer.get("rowHeight")
    s = svg.base height: 20, width: totalWidth
    s.type = "selection"
    s.style.position = "absolute"
    s.style.left = 0
    hidden = @g.columns.get('hidden')

    # split up the selection into single cells
    xPart = 0
    for i in [0.. selectionLength - 1]
      xPos = n + i
      if hidden.indexOf(xPos) >= 0
        continue
      # upper line
      unless mPrevSel? and mPrevSel.indexOf(xPos) >= 0
        s.appendChild svg.line x1:xPart,y1:0,x2:xPart + width,y2:0,style:
          "stroke:red;stroke-width:2;"
      # lower line
      unless mNextSel? and mNextSel.indexOf(xPos) >= 0
        s.appendChild svg.line x1:xPart,y1:cHeight,x2:xPart + width,y2:cHeight,style:
          "stroke:red;stroke-width:1;"
      xPart += width

    s.appendChild svg.line x1:0,y1:0,x2:0,y2:cHeight,style:
      "stroke:red;stroke-width:2;"
    s.appendChild svg.line x1:totalWidth,y1:0,x2:totalWidth,y2:cHeight,style:
      "stroke:red;stroke-width:2;"
    return s

  appendFeature: (f) ->
    # TODO: experimenting with different views
    # TODO: this is a very naive way of using SVG to display features
    width = (f.get("xEnd") - f.get("xStart")) * 15
    s = svg.base(height: 20, width: width + 2)
    color = f.get "fillColor"
    cHeight = @g.zoomer.get("rowHeight")
    s.style.marginTop = -1
    s.appendChild svg.rect x:1,y:1,width:width - 1,height:cHeight - 1,style:
      "stroke: " + color + ";stroke-width: 3;fill-opacity: 0"
    s.style.position = "absolute"
    s.style.left = 0
    jbone(s).on "mouseover", (evt) =>
      @g.trigger "feature",  f.get("text") + " hovered"
    s

  removeViews: ->
    console.log "seq removed"

module.exports = SeqView
