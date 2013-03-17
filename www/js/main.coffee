
window.global =
  width: 1020
  height: 600


global.renderer = new THREE.WebGLRenderer
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



landerGeometry = new THREE.Geometry()

pushVertices landerGeometry, [
  vertex -15, -15
  vertex 15, -15
  vertex 15, 15
  vertex -15, 15
]

pushFaces landerGeometry, [
  face4 3,2,1,0
]


atlas = THREE.ImageUtils.loadTexture "img/textures.png"

atlas_w = 1022
atlas_h = 1520

landerGeometry = new THREE.PlaneGeometry(30, 30, 1, 1)
vector2 = (x,y)-> new THREE.Vector2(x,y)
spriteW = 64 / atlas_w
spriteH = 64 / atlas_h


jsonLoader = new THREE.JSONLoader()

global.landerMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    transparent: true
    side: THREE.DoubleSide
    shading: THREE.FlatShading
    map: atlas
    overdraw: true


global.levelMaterial = new THREE.MeshBasicMaterial
    color: 0xffffff
    side: THREE.DoubleSide
    shading: THREE.FlatShading
    overdraw: true

global.resourceCount = 0

countDown = (func)->
  global.resourceCount += 1
  return ->
    func(arguments...)
    global.resourceCount -= 1
    
zeroFill = (i,n)->
  a = []
  for j in [0..(Math.floor(Math.log(i)/ Math.log(10))-n+2)]
    a.push "0"
  return a.join("")+i

landerFrameUvs = []
$.get 'js/textures.json', {}, countDown (data)->
  for i in [1..100]
    s = 'lander'+zeroFill(i, 4)+'.png'
    frame = data.frames[s].frame
    landerFrameUvs.push vector2(frame.x / atlas_w, frame.y / atlas_h)

class Game
  constructor: ()->
    gravity = new b2Vec2(0, 10)
    # create a temporary ground
    @world = new b2World(gravity, true)
    @lander = new Lander(@)


    body = $("body")
    body.keydown @keyDown
    body.keyup @keyUp
    @pressedKeys = {}
    jsonLoader.load "js/level1.js", (model)=>
      global.levelModel = model
      @level = new THREE.Mesh(global.levelModel, global.levelMaterial)
      global.scene.add(@level)
      @level.position.x = 0
      @level.position.y =-10
      @level.position.z = -1
      @level.scale.y = -1
      @level.scale.x = 1
    
      verts = model.vertices
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
          v1 = new b2Vec2(verts[a].x, -verts[a].y)
          v2 = new b2Vec2(verts[b].x, -verts[b].y)
          @makeEdge(v1, v2)
  keyDown: (event)=>
    @pressedKeys[event.keyCode] = true
  keyUp: (event)=>
    @pressedKeys[event.keyCode] = false

  mainLoop: =>
    newFrame = new Date().getTime()
    dt = (newFrame-@lastFrame)/1000
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
    @lander.update(dt)
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
class Lander
  constructor: (game)->
    bodyDef = new b2BodyDef
    @bodyDef = bodyDef
    bodyDef.type = b2Body.b2_dynamicBody
    bodyDef.position.x = 0
    bodyDef.position.y = 0
    bodyDef.angle = 0
    body = game.world.CreateBody(bodyDef)
    body.test = "test"
    @body = body
    body.w = 15
    body.h = 20
    fixtureDef = new b2FixtureDef
    fixtureDef.restitution = 0.0
    fixtureDef.density = 5000.0 / body.w / body.h
    fixtureDef.friction = 0.9
    shape = new b2PolygonShape.AsBox(body.w, body.h)
    fixtureDef.shape = shape
    body.CreateFixture(fixtureDef)
    @mesh = new THREE.Mesh(landerGeometry, global.landerMaterial)
    global.scene.add(@mesh)
    @steering = 0

  update: (dt)->
    x = @body.GetPosition().x
    y = @body.GetPosition().y
    @mesh.position.x = x
    @mesh.position.y = y
    a = @body.GetAngle()
    @body.m_torque=(1000000000*dt*@steering)
    thrust = 20000000*dt*@thrust
    f = new b2Vec2(thrust*Math.sin(a), -thrust*Math.cos(a))
    p1 = new b2Vec2(x, y)
    @body.ApplyForce(f, p1)
    if landerFrameUvs.length>0
      if a<0
        a = Math.PI*2 + (a % (Math.PI*2))
      frame = Math.floor(a/Math.PI/2 *100+25)%100
      v = landerFrameUvs[frame]
      landerGeometry.faceVertexUvs = [[[
        vector2 v.x, 1-v.y
        vector2 v.x+spriteW,1-v.y
        vector2 v.x+spriteW,1-v.y-spriteH
        vector2 v.x,1-v.y-spriteH
      ]]]
      landerGeometry.uvsNeedUpdate = true
      # Adjust residual rotation
      @mesh.rotation.z = a-((frame-25)/100.0 * Math.PI * 2)
game = new Game()
game.launch()
