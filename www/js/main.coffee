
window.global =
  width: 1024
  height: 600
  resourceCounter: 0

# Standard javascript modulo operator returns negative values, so we need our
# own
window.signedMod = (a,b)->
  return if a < 0 then b+a%b else a%b
b2Scale = 0.01
global.renderer = new THREE.CanvasRenderer
  canvas: $("canvas")[0]

global.renderer.setSize(global.width, global.height)
ctx = $("canvas#status")[0].getContext('2d')

vertex = (x,y,z)->
  if z is undefined
    z = 0
  return new THREE.Vector3(x,y,z)

pushVertices = (geometry, vertices)->
  for v in vertices
    geometry.vertices.push(v)

face3 = (a,b,c)->
  return new THREE.Face3(a,b,c)

face4 = (a,b,c,d)->
  return new THREE.Face4(a,b,c,d)
pushFaces = (geometry, faces)->
  for f in faces
    geometry.faces.push(f)


atlas = THREE.ImageUtils.loadTexture "img/textures.png"

atlas_w = 2048
atlas_h = 1058

vector2 = (x,y)-> new THREE.Vector2(x,y)


jsonLoader = new THREE.JSONLoader()

global.landerMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    transparent: true
    side: THREE.DoubleSide
    shading: THREE.FlatShading
    transparency: true
    map: atlas
    overdraw: true
    wireframe: true

global.exhaustMaterial = global.landerMaterial.clone()
global.exhaustMaterial.opacity = 0.2
global.exhaustMaterial.blending = THREE.AdditiveBlending
global.debugMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    wireframe: true
    shading: THREE.FlatShading
    side: THREE.DoubleSide
terrainSurface = THREE.ImageUtils.loadTexture "img/lunarsurface.png"
terrainSurface.wrapS = THREE.RepeatWrapping 
terrainSurface.wrapT = THREE.RepeatWrapping 
global.levelMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    side: THREE.DoubleSide
    shading: THREE.FlatShading
    overdraw: true
    map: terrainSurface


    
zeroFill = (i,n)->
  a = []
  for j in [0..(Math.floor(Math.log(i)/ Math.log(10))-n+2)]
    a.push "0"
  return a.join("")+i

# Decorator to count down resource loads
countedCallback = (func)->
  global.resourceCounter+=1
  return ->
    global.resourceCounter -= 1
    func(arguments...)
    console.log "Resources left:", global.resourceCounter
    if global.resourceCounter == 0
      launch()

landerFrameUvs = []
rocketFrameUvs = []
exhaustFrameUvs = []
baseFrameUvs = []

$.getJSON 'js/textures.json', {}, countedCallback (data)->
  for [name, array, frames] in [
    ["lander", landerFrameUvs, 100]
    ["rocket", rocketFrameUvs, 100]
    ["exhaust", exhaustFrameUvs, 25]
    ["base", baseFrameUvs, 64]
  ]
    for i in [1..frames]
      s = name+zeroFill(i, 4)+'.png'
      frame = data.frames[s].frame
      array.push vector2(frame.x / atlas_w, frame.y / atlas_h)

class Game
  constructor: ()->
    gravity = new b2Vec2(0, 15*b2Scale)
    # create a temporary ground
    @quit = false
    @entities = []
    @bases = []
    @basesDestroyed = 0
    @world = new b2World(gravity, true)
    bodyDef = new b2BodyDef()
    bodyDef.type = b2Body.b2_staticBody
    bodyDef.position.x = 0
    bodyDef.position.y = 0
    bodyDef.angle = 0
    @terrainBody = @world.CreateBody(bodyDef)

    body = $("body")
    preventDefault = (func)->
      (event)->
        r = func(event)
        event.preventDefault()
        return r

    body.keydown @keyDown
    body.keyup @keyUp
    @pressedKeys = {}
    @terminal = new Terminal()
    @terminal.display("Destroy the missile bases by landing on them...")
    @scene = new THREE.Scene()

    @camera = new THREE.OrthographicCamera(- window.global.width / 4,
                                                  window.global.width / 4,
                                                - window.global.height / 4,
                                                  window.global.height / 4,
                                                  -10, 3000)
    @camera.position.z = 1000
    @scene.add(@camera)

    @lander = new Lander(@)
    new THREE.JSONLoader().load "js/level1.js", (model)=>
      # Take Terrain from Mesh
      @level = new THREE.Mesh(model, global.levelMaterial)
      @scene.add(@level)
      @level.position.x = 0
      @level.position.y = 0
      @level.position.z = -4
      @level.scale.y = -1
      @level.scale.x = 1

      verts = model.vertices
      # Detect "Outer" edges by counting the occurrences of the vertex
      # combinations. Outer edges are used exactly once, while inner edges
      # pair up.
      #
      edges = {}
      countEdge =(a,b)->
        v = [a,b]
        v.sort()
        [a,b] = v
        s = "#{a}-#{b}"
        edges[s] = if edges[s]? then edges[s]+1 else 1

      for face in model.faces
        countEdge face.a, face.b
        countEdge face.b, face.c
        if face.d?
            countEdge face.c, face.d
            countEdge face.d, face.a
        else
            countEdge face.c, face.a

      for edge,count of edges
        if count==1
          [a,b] = edge.split("-")
          v1 = new b2Vec2(verts[a].x * b2Scale, -verts[a].y * b2Scale)
          v2 = new b2Vec2(verts[b].x * b2Scale, -verts[b].y * b2Scale)
          @makeEdge(v1, v2)

      # Data about entities is kept as bones
      # No particular reason for using bones except it works nicely and without
      # modifying threejs, blender or the exporter

      for bone in model.bones
        [x,y] = bone.pos
        new Rocket
          game: @
          x: x
          y: -y-13
        new MissileBase
          game: @
          x: x
          y: -y
    @listener = new b2ContactListener()
    @listener.PostSolve = (contact, impulse) =>
      fixA = contact.GetFixtureA()
      fixB = contact.GetFixtureB()
      isContactBetween = (id1,id2)->
        return ((fixA.m_userData == id1) and (fixB.m_userData == id2)) \
         or ((fixA.m_userData== id2) and (fixB.m_userData == id1))
      sumImpulses = (contact)->
        points = contact.GetManifold().m_points
        totalImpulse = 0
        for point in points
            totalImpulse+=point.m_normalImpulse
        return totalImpulse
      if isContactBetween 'terrain', 'landingGear'
        totalImpulse = sumImpulses contact
        threshold = 5000000
        if totalImpulse>threshold
          @lander.damage += (totalImpulse-threshold) / 100000

                  
    @world.SetContactListener(@listener)
  keyDown: (event)=>
    @pressedKeys[event.keyCode] = true
    for code in [37, 38, 39]
      if event.keyCode == code
        event.preventDefault()
  keyUp: (event)=>
    @pressedKeys[event.keyCode] = false

  mainLoop: (newFrame)=>
    if newFrame?
      dt = (newFrame-@lastFrame)/1000
      if dt>2 then dt = 0.01
      if (dt==0) or isNaN(dt)
        dt = 0.0001
    else
      dt = 0.0001
    @lastFrame = newFrame
    if @pressedKeys[82]
      @quit = true
    if @quit
      game = new Game()
      game.launch()
    else
      requestAnimationFrame(@mainLoop)
    @lander.steering = 0
    if @pressedKeys[37]
      @lander.steering = -1

    if @pressedKeys[39]
      @lander.steering = 1
    
    @lander.thrust = if @pressedKeys[38] then 1 else 0
    @world.Step(dt, 5, 5)
    @world.ClearForces()
    for entity in @entities
      entity.update dt

    @camera.position.x = @lander.mesh.position.x
    @camera.position.y = @lander.mesh.position.y
    global.renderer.render(@scene, @camera)
    ctx.clearRect(0,0,200,100)
    ctx.fillStyle = "#00ff22"
    ctx.font = "bold 12pt vt220"
    ctx.fillText("Fuel: #{@lander.fuel.toFixed(1)}s", 0,15)
    ctx.fillText("Damage: #{@lander.damage.toFixed(1)}%", 0,30)
    @terminal.update(dt)
    @terminal.draw()


  launch:()->
    @lastFrame = new Date().getTime()
    @mainLoop()

  makeEdge:(v1,v2)->
    fixtureDef = new b2FixtureDef()
    fixtureDef.restitution = 0.1
    fixtureDef.density = 2.0
    fixtureDef.friction = 0.7
    fixtureDef.userData = "terrain"
    shape = new b2PolygonShape.AsEdge(v1,v2)
    fixtureDef.shape = shape
    @terrainBody.CreateFixture(fixtureDef)

class RotationalSprite
  constructor: (config)->
    @game = config.game
    @game.entities.push @
    @atlasUvs = config.atlasUvs
    @spriteW = config.spriteW
    @spriteH = config.spriteH
    @angleOffset = config.angleOffset
    @createBody(config)
    @geometry = new THREE.PlaneGeometry(config.sideLength/2, config.sideLength/2, 1, 1)
    @mesh = new THREE.Mesh(@geometry, global.landerMaterial)
    @game.scene.add(@mesh)
    @steering = 0
  createBody: ->
    undefined
  setPosition: (x,y) ->
    @body.SetPosition (new b2Vec2(x,y))

  update: (dt)->
    x = @body.GetPosition().x / b2Scale
    y = @body.GetPosition().y / b2Scale
    @mesh.position.x = x
    @mesh.position.y = y
    @mesh.position.z = -1
    a = @body.GetAngle()+Math.PI/2
    if @atlasUvs.length>0
      a = signedMod(a,Math.PI*2)
      frame = Math.floor signedMod(a/Math.PI/2 *99+@angleOffset, 100)
      v = @atlasUvs[frame]
      @geometry.faceVertexUvs = [[[
        vector2 v.x, 1-v.y
        vector2 v.x+@spriteW,1-v.y
        vector2 v.x+@spriteW,1-v.y-@spriteH
        vector2 v.x,1-v.y-@spriteH
      ]]]
      @geometry.uvsNeedUpdate = true
      # Adjust residual rotation
      @mesh.rotation.z = a-((frame-@angleOffset)/99.0 * Math.PI * 2)

class Lander extends RotationalSprite
  constructor: (game) ->
    super
      game: game
      atlasUvs: landerFrameUvs
      width: 9
      height: 2
      mass : 1000000
      spriteW: 64 / atlas_w
      spriteH: 64 / atlas_h
      x: 0
      y: 0
      angleOffset: 0
      sideLength: 64
      friction: 0.2
    @fuel = 25
    @damage = 0
    @exhaustGeometry = new THREE.PlaneGeometry(32, 32, 1, 1)
    @exhaustMesh = new THREE.Mesh(@exhaustGeometry, global.exhaustMaterial)
    @exhaustStrength = 0
    @exhaustCycle = 0
    @game.scene.add(@exhaustMesh)
  createBody: (config)->
    bodyDef = new b2BodyDef
    @bodyDef = bodyDef
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = config.x * b2Scale
    bodyDef.position.y = config.y * b2Scale
    # set very small angle difference, otherwise the lander survives
    # the initial fall without harm
    bodyDef.angle = 0.01
    body = @game.world.CreateBody(bodyDef)
    body.test = "test"
    @body = body
    body.w = config.width * b2Scale
    body.h = config.height * b2Scale
    fixtureDef = new b2FixtureDef
    fixtureDef.restitution = 0.1
    fixtureDef.density = config.mass / body.w / body.h
    fixtureDef.friction = config.friction
    fixtureDef.shape = new b2PolygonShape.AsOrientedBox(body.w, body.h, new b2Vec2(0,4*b2Scale),0)
    fixtureDef.userData = "landingGear"
    body.CreateFixture(fixtureDef)
    fixtureDef = new b2FixtureDef
    fixtureDef.restitution = 0.1
    fixtureDef.density = config.mass / body.w / body.h
    fixtureDef.friction = 0.4
    fixtureDef.shape = new b2CircleShape(4*b2Scale)
    fixtureDef.shape.SetLocalPosition(new b2Vec2(0,-5*b2Scale))
    fixtureDef.userData = "landerSphere"
    body.CreateFixture(fixtureDef)

  update: (dt)->
    x = @body.GetPosition().x / b2Scale
    y = @body.GetPosition().y / b2Scale
    a = @body.GetAngle()
    vel = @game.lander.body.GetLinearVelocity()
    @velD = Math.sqrt(vel.x*vel.x+vel.y*vel.y)
    @vel = vel
    @body.m_torque=(2000000*dt*@steering)
    @fuel -= (if @thrust then 1 else 0)*dt
    @fuel = Math.max(0,@fuel)
    if @fuel == 0
      unless @outOfFuel?
        @outOfFuel = true
        @game.terminal.display "Out of Fuel. Press 'r' to retry ..."
      @thrust = 0
    @exhaustStrength += (if @thrust then 1 else -1)* 5 * dt
    @exhaustStrength = Math.min(Math.max(@exhaustStrength,0), 1)
    global.exhaustMaterial.opacity = @exhaustStrength
    thrust = 100000000*dt*@thrust
    f = new b2Vec2(thrust*Math.sin(a), -thrust*Math.cos(a))
    p1 = new b2Vec2(x*b2Scale, y*b2Scale)
    @body.ApplyForce(f, p1)
    super dt
    # Update exhaust plume
    @exhaustCycle += dt*15
    @exhaustCycle %= 25
    frame = Math.floor @exhaustCycle
    v = exhaustFrameUvs[frame]
    w = 64 /atlas_w
    h = 64 /atlas_h
    @exhaustGeometry.faceVertexUvs = [[[
      vector2 v.x, 1-v.y
      vector2 v.x+w,1-v.y
      vector2 v.x+w,1-v.y-h
      vector2 v.x,1-v.y-h
    ]]]
    @exhaustGeometry.uvsNeedUpdate = true
    @exhaustMesh.position.x = x
    @exhaustMesh.position.y = y
    @exhaustMesh.position.z = 10
    @exhaustMesh.rotation.z = a+Math.PI/2

class Rocket extends RotationalSprite
  constructor: (config) ->
    config.game = config.game
    config.atlasUvs =  rocketFrameUvs
    config.width = 2.6
    config.height = 15
    config.sideLength = 100
    config.spriteW = 100 / atlas_w
    config.spriteH = 100 / atlas_h
    config.friction = 0.1
    config.mass = 10000000
    config.angleOffset = 0
    super config
    @mesh.position.z = -1

  createBody: (config)->
    bodyDef = new b2BodyDef
    @bodyDef = bodyDef
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = config.x * b2Scale
    bodyDef.position.y = config.y * b2Scale
    bodyDef.angle = 0
    body = @game.world.CreateBody(bodyDef)
    body.test = "test"
    @body = body
    body.w = config.width * b2Scale
    body.h = config.height * b2Scale
    fixtureDef = new b2FixtureDef
    fixtureDef.restitution = 0.1
    fixtureDef.density = config.mass / body.w / body.h
    fixtureDef.friction = config.friction
    shape = new b2PolygonShape.AsBox(body.w, body.h)
    fixtureDef.shape = shape
    body.CreateFixture(fixtureDef)
  update: (dt)=>
    super dt


class AnimatedSprite
  constructor: (config)->
    @game = config.game
    @game.entities.push @
    @atlasUvs = config.atlasUvs
    @spriteW = config.spriteW
    @spriteH = config.spriteH
    @screenWidth = config.screenWidth
    @screenHeight = config.screenHeight

    @geometry = new THREE.PlaneGeometry(@screenWidth / 2, @screenHeight / 2, 1, 1)
    @mesh = new THREE.Mesh(@geometry, global.landerMaterial)
    @game.scene.add(@mesh)
    @x = config.x
    @y = config.y
    @z = config.z
    @frame = 0
    @update(0.0001)
  update: (dt)->
    @mesh.position.x = @x
    @mesh.position.y = @y
    @mesh.position.z = @z
    @mesh.rotation.z = Math.PI/2

    v = @atlasUvs[Math.floor @frame]
    w = @spriteW / atlas_w
    h = @spriteH / atlas_h
    @geometry.faceVertexUvs = [[[
      vector2 v.x, 1-v.y
      vector2 v.x+w,1-v.y
      vector2 v.x+w,1-v.y-h
      vector2 v.x,1-v.y-h
    ]]]
    @geometry.uvsNeedUpdate = true


class MissileBase extends AnimatedSprite
  constructor: (config)->
    @exploded = false
    super
      game: config.game
      x: config.x
      y: config.y-10
      z: -2
      spriteW: 80
      spriteH: 80
      screenWidth: 80
      screenHeight: 80
      atlasUvs: baseFrameUvs
    @game.bases.push @
  update: (dt)=>
    if @exploded
      @frame+=dt*15
      @frame = Math.min(@frame, 63)
    super dt
    if @game.lander.velD< 0.01
      if Math.abs(@x-@game.lander.mesh.position.x)<7
        if Math.abs(@y-@game.lander.mesh.position.y-5)<20
          if Math.abs(signedMod(@game.lander.body.GetAngle(), Math.PI*2))<Math.PI/360*10
            unless @exploded
              @game.basesDestroyed += 1
              @exploded = true
              @game.lander.fuel =Math.min(@game.lander.fuel+15, 45)
              print = (s)=> @game.terminal.display(s)
              switch @game.basesDestroyed
                when 1
                  print "The eagle has landed..."
                when 2
                  print "One small step for man..."
                  print "One huge BOOM for mankind..."

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
    console.log line
    @queuedLines.push line
  draw: ()->
    @ctx.clearRect(0,0,500,500)
    @ctx.fillStyle = "#00ff22"
    @ctx.font = "bold 12pt vt220"
    numLines = @displayedLines.length
    y = 0
    lineH = 15
    if numLines > 1
      for i in [Math.max(0,numLines-5)..Math.max(0, numLines-2 )]
        @ctx.fillText(@displayedLines[i], 0, y+lineH)
        y+=lineH
    if numLines >0
        @ctx.fillText(@displayedLines[numLines-1].substr(0,Math.round(@column)), 0, y+lineH)
launch = ->
    game = new Game()
    game.launch()
