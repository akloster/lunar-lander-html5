###
#  Baseclass for Sprites that have pre-rendered rotations.
#  Essentially we have certain number of raytraced rotation
#  images, then we use normal rotation on the canvas for finer
#  control.
#
#  Sprites are simple plane meshes.
#  
###
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
    config.scene.add(@mesh)
    @steering = 0
    @z = config.z
  createBody: ->
    undefined
  setPosition: (x,y) ->
    @body.SetPosition (new b2Vec2(x,y))

  update: (dt)->
    x = @body.GetPosition().x / b2Scale
    y = @body.GetPosition().y / b2Scale
    @mesh.position.x = x
    @mesh.position.y = y
    @mesh.position.z = @z
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
      z: global.landerZ
      scene: game.scene
      angleOffset: 0
      sideLength: 64
      friction: 0.7
    @fuel = 30
    @damage = 0
    @exhaustGeometry = new THREE.PlaneGeometry(32, 32, 1, 1)
    @exhaustMesh = new THREE.Mesh(@exhaustGeometry, global.exhaustMaterial)
    @exhaustStrength = 0
    @exhaustCycle = 0

    game.scene.add(@exhaustMesh)
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
    @body.m_torque=(2800000*dt*@steering)
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
    if global.engine?
      global.engine.setVolume(0.2*@exhaustStrength)
    thrust = 150000000*dt*@thrust
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
    @exhaustMesh.position.z = global.exhaustZ
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
    config.scene = config.game.scene
    config.z = global.rocketZ+ Math.random()*20
    super config

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
      z: global.baseZ+Math.random()*20
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
      if Math.abs(@x-@game.lander.mesh.position.x)<9
        if Math.abs(@y-@game.lander.mesh.position.y-10)<30
          if Math.abs(signedMod(@game.lander.body.GetAngle(), Math.PI*2))<Math.PI/360*10
            unless @exploded
              @game.basesDestroyed += 1
              if @game.basesDestroyed == @game.basesTotal
                @game.levelUp()
              @exploded = true
              @game.lander.fuel =Math.min(@game.lander.fuel+15, 45)
              print = (s)=> @game.terminal.display(s)
              if @game.levelNumber==1
                switch @game.basesDestroyed
                  when 1
                    print "The eagle has landed..."
                  when 2
                    print "One small step for man..."
                    print "One huge BOOM for mankind..."

