class Game
  constructor: (levelNumber)->
    @levelNumber = levelNumber
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
    if @levelNumber == 1
      @terminal.display("Destroy the missile bases by landing on them...")
    else
      @terminal.display("Level #{@levelNumber}...")
    @scene = new THREE.Scene()

    @camera = new THREE.OrthographicCamera(- window.global.width / 4,
                                                  window.global.width / 4,
                                                - window.global.height / 4,
                                                  window.global.height / 4,
                                                  -10, 3000)
    @camera.position.z = 1000
    @scene.add(@camera)

    @lander = new Lander(@)
    new THREE.JSONLoader().load "js/level#{@levelNumber}.js", (model)=>
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
      @basesTotal = model.bones.length
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
      # When level loading is finished, start game
      @launch()
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

      if isContactBetween('terrain', 'landingGear') or isContactBetween('terrain', 'landerSphere')
        @lander.frameImpulse += sumImpulses contact
        vel = @lander.body.GetLinearVelocity()
        velocity = Math.sqrt(vel.x*vel.x + vel.y*vel.y)
        maxVel = 0.5
        if (velocity)>maxVel
          @lander.damage += Math.max(10, (velocity-maxVel)/10)
      
                  

    @world.SetContactListener(@listener)
  keyDown: (event)=>
    @pressedKeys[event.keyCode] = true
    for code in [37, 38, 39]
      if event.keyCode == code
        event.preventDefault()
  keyUp: (event)=>
    @pressedKeys[event.keyCode] = false

  levelUp: =>
    @levelNumber += 1
    @quit = true

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
      if @levelNumber==4
        # Establish winscreen
        $("canvas").hide()
        $("#winscreen").show()
      else
        # Restart Game
        game = new Game(@levelNumber)
      return
    else
      requestAnimationFrame(@mainLoop)
    @lander.steering = 0
    if @pressedKeys[37]
      @lander.steering = -1

    if @pressedKeys[39]
      @lander.steering = 1
    
    @lander.thrust = if @pressedKeys[38] then 1 else 0
    if @lander.destroyed
      @lander.thrust = 0
      @lander.steering = 0
    @lander.frameImpulse = 0
    steps = dt* 60*60*5
    @world.Step(dt, steps, steps)
    @world.ClearForces()
    for entity in @entities
      entity.update dt
    if @lander.damage>=100
      @lander.damage = 100
      unless @lander.destroyed?
        @terminal.display("Houston, we have a problem...")
        @terminal.display("The Lander is kaputt. Press 'r'")
        @lander.destroyed=true
        



    @camera.position.x = @lander.mesh.position.x
    @camera.position.y = @lander.mesh.position.y
    global.renderer.render(@scene, @camera)
    ctx.clearRect(0,0,200,100)
    ctx.fillStyle = "#00ff22"
    ctx.font = "bold 13pt vt220"
    ctx.fillText("Fuel: #{@lander.fuel.toFixed(1)}s", 0,15)
    ctx.fillText("Damage: #{@lander.damage.toFixed(1)}%", 0,30)
    ctx.fillText("Bases destroyed: #{@basesDestroyed}/#{@basesTotal}", 0,45)
    @terminal.update(dt)
    @terminal.draw()


  launch:()->
    @lastFrame = new Date().getTime()
    if global.music?
      global.music.setVolume(global.musicVolume)
    if global.engine?
      global.engine.setVolume(0)
      global.engine.play()
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

