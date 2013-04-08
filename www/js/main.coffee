window.global =
  width: 1024
  height: 600
  resourceCounter: 0
  musicVolume: 0.2

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
playLooped = (id)-> createjs.Sound.play(id, "none", 0,0,-1)
createjs.Sound.addEventListener("loadComplete", (event) ->
  if event.id == "music"
    global.music = playLooped("music")
    global.music.setVolume(global.musicVolume)
  if event.id == "engine"
    global.engine = playLooped("engine")
    global.engine.setVolume(0)
)

createjs.Sound.registerSound("audio/therapy_season.mp3", "music")
createjs.Sound.registerSound("audio/engine.mp3", "engine")


launch = ->
    game = new Game(1)
    game.quit = true
