###
# Retro-looking Terminal Emulator
###

class Terminal
  constructor: ->
    @queuedLines = []
    @displayedLines =[]
    @column = 0
    @ctx = $("canvas#terminal")[0].getContext('2d')
    @removalTime = 0
  update: (dt) ->
    if @displayedLines.length>0
      @column += dt*15
      currentLineWidth = @displayedLines[@displayedLines.length-1].length
      @removalTime += dt
      if @removalTime > 5
        if @displayedLines.length>0
            line = @displayedLines.shift()
            if @displayedLines.length >0
              currentLineWidth = @displayedLines[@displayedLines.length-1].length
            else
              currentLineWidth = -1
        @removalTime = 0
    else
      currentLineWidth = -1
      @removalTime = 0
    if @column > currentLineWidth
      @column = Math.max(0,currentLineWidth)
      if @queuedLines.length > 0
        line = @queuedLines.shift()
        @displayedLines.push line
        @column = 0
        if @displayedLines.length==1
          @removalTime = 0
  display: (line)=>
    @queuedLines.push line
  draw: ()->
    @ctx.clearRect(0,0,500,500)
    @ctx.fillStyle = "#00ff22"
    @ctx.font = "bold 13pt vt220"
    numLines = @displayedLines.length
    y = 0
    lineH = 15
    if numLines > 1
      for i in [Math.max(0,numLines-5)..Math.max(0, numLines-2 )]
        @ctx.fillText(@displayedLines[i], 0, y+lineH)
        y+=lineH
    if numLines >0
        @ctx.fillText(@displayedLines[numLines-1].substr(0,Math.round(@column)), 0, y+lineH)
