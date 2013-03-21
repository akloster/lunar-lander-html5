
window.global =
  width: 1020
  height: 600
  resourceCounter: 0

signedMod = (a,b)->
  return if a < 0 then b+a%b else a%b
console.log '>',signedMod(-5, 10)
b2Scale = 0.01
global.renderer = new THREE.CanvasRenderer
  canvas: $("canvas")[0]

global.scene = new THREE.Scene()

global.camera = new THREE.OrthographicCamera(- window.global.width / 4,
                                               window.global.width / 4,
                                             - window.global.height / 4,
                                               window.global.height / 4,
                                               1, 3000)
global.camera.position.z = 1000
global.scene.add(global.camera)
global.renderer.setSize(global.width, global.height)

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

atlas_w = 1022
atlas_h = 1520

vector2 = (x,y)-> new THREE.Vector2(x,y)


jsonLoader = new THREE.JSONLoader()

global.landerMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    transparent: true
    side: THREE.DoubleSide
    shading: THREE.FlatShading
    map: atlas
    overdraw: true


global.debugMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    wireframe: true#shading: THREE.FlatShading
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
$.getJSON 'js/textures.json', {}, countedCallback (data)->
  for [name, array] in [["lander", landerFrameUvs], ["rocket", rocketFrameUvs] ]
    for i in [1..100]
      s = name+zeroFill(i, 4)+'.png'
      frame = data.frames[s].frame
      array.push vector2(frame.x / atlas_w, frame.y / atlas_h)

class Game
  constructor: ()->
    gravity = new b2Vec2(0, 10*b2Scale)
    # create a temporary ground
    @world = new b2World(gravity, true)
    @entities = []
    @lander = new Lander(@)

    body = $("body")
    preventDefault = (func)->
      (event)->
        r = func(event)
        event.preventDefault()
        return r

    body.keydown @keyDown
    body.keyup @keyUp
    @pressedKeys = {}
    new THREE.JSONLoader().load "js/level1.js", (model)=>
      # Take Terrain from Mesh
      @level = new THREE.Mesh(model, global.levelMaterial)
      global.scene.add(@level)
      @level.position.x = 0
      @level.position.y = 0
      @level.position.z = -1
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
          x: x #x * b2Scale
          y: -y
    @debugGeometry = new THREE.Geometry()
    @debugMesh = new THREE.Mesh(@debugGeometry, global.debugMaterial)
  keyDown: (event)=>
    @pressedKeys[event.keyCode] = true
  keyUp: (event)=>
    @pressedKeys[event.keyCode] = false

  mainLoop: =>
    newFrame = new Date().getTime()
    dt = (newFrame-@lastFrame)/1000
    if dt>2 then dt = 0.01
    @lastFrame = newFrame
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

    @debugGeometry.vertices =[]
    @debugGeometry.faces = []
    pushVertices @debugGeometry,[ 
        vertex 0,0, -1
        vertex 100,0, -1
        vertex 0,100,-1]
    pushFaces @debugGeometry,[
        face3 0,1,2]
    @debugGeometry.verticesNeedUpdate = true
    global.camera.position.x = @lander.mesh.position.x
    global.camera.position.y = @lander.mesh.position.y
    global.renderer.render(global.scene, global.camera)


  launch:()->
    @lastFrame = new Date().getTime()
    @mainLoop()

  makeEdge:(v1,v2)->
    bodyDef = new b2BodyDef()
    bodyDef.type = b2Body.b2_staticBody
    bodyDef.position.x = 0
    bodyDef.position.y = 0
    bodyDef.angle = 0
    body = @world.CreateBody(bodyDef)
    fixtureDef = new b2FixtureDef()
    fixtureDef.restitution = 0.0
    fixtureDef.density = 2.0
    fixtureDef.friction = 0.9
    shape = new b2PolygonShape.AsEdge(v1,v2)
    fixtureDef.shape = shape
    body.CreateFixture(fixtureDef)

class RotationalSprite
  constructor: (config)->
    @game = config.game
    @game.entities.push @
    @atlasUvs = config.atlasUvs
    @spriteW = config.spriteW
    @spriteH = config.spriteH
    @angleOffset = config.angleOffset
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
    fixtureDef.friction = 0.7
    shape = new b2PolygonShape.AsBox(body.w, body.h)
    fixtureDef.shape = shape
    body.CreateFixture(fixtureDef)
    @geometry = new THREE.PlaneGeometry(config.sideLength/2, config.sideLength/2, 1, 1)
    @mesh = new THREE.Mesh(@geometry, global.landerMaterial)
    global.scene.add(@mesh)
    @steering = 0

  setPosition: (x,y) ->
    @body.SetPosition (new b2Vec2(x,y))

  update: (dt)->
    x = @body.GetPosition().x / b2Scale
    y = @body.GetPosition().y / b2Scale
    @mesh.position.x = x
    @mesh.position.y = y
    a = @body.GetAngle()+Math.PI/2
    if @atlasUvs.length>0
      a = signedMod(a,Math.PI*2)
      frame = signedMod(Math.floor((a/Math.PI/2) *100)+@angleOffset, 100)
      v = @atlasUvs[frame]
      @geometry.faceVertexUvs = [[[
        vector2 v.x, 1-v.y
        vector2 v.x+@spriteW,1-v.y
        vector2 v.x+@spriteW,1-v.y-@spriteH
        vector2 v.x,1-v.y-@spriteH
      ]]]
      @geometry.uvsNeedUpdate = true
      # Adjust residual rotation
      @mesh.rotation.z = a-((frame-@angleOffset)/100.0 * Math.PI * 2)

class Lander extends RotationalSprite
  constructor: (game) ->
    super
      game: game
      atlasUvs: landerFrameUvs
      width: 11
      height: 6
      mass : 1000000
      spriteW: 64 / atlas_w
      spriteH: 64 / atlas_h
      x: 0
      y: 0
      angleOffset: 0
      sideLength: 64
  update: (dt)->
    x = @body.GetPosition().x / b2Scale
    y = @body.GetPosition().y / b2Scale
    a = @body.GetAngle()
    @body.m_torque=(2000000*dt*@steering)
    thrust = 80000000*dt*@thrust
    f = new b2Vec2(thrust*Math.sin(a), -thrust*Math.cos(a))
    p1 = new b2Vec2(x*b2Scale, y*b2Scale)
    @body.ApplyForce(f, p1)
    super dt

class Rocket extends RotationalSprite
  constructor: (config) ->
    config.game = config.game
    config.atlasUvs =  rocketFrameUvs
    config.width = 7
    config.height = 18
    config.sideLength = 100
    config.spriteW = 100 / atlas_w
    config.spriteH = 100 / atlas_h
    config.mass = 20000000
    config.angleOffset =0
    super config
    @mesh.position.z = -1
  update: (dt)->
    #console.log @body.GetAngle() / Math.PI/2 * 360
    super dt

launch = ->
    game = new Game()
    game.launch()
