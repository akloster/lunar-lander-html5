// Generated by CoffeeScript 1.4.0
(function() {
  var Game, Lander, Rocket, RotationalSprite, atlas, atlas_h, atlas_w, b2Scale, countedCallback, face3, face4, jsonLoader, landerFrameUvs, launch, pushFaces, pushVertices, rocketFrameUvs, signedMod, terrainSurface, vector2, vertex, zeroFill,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  window.global = {
    width: 1020,
    height: 600,
    resourceCounter: 0
  };

  signedMod = function(a, b) {
    if (a < 0) {
      return b + a % b;
    } else {
      return a % b;
    }
  };

  console.log('>', signedMod(-5, 10));

  b2Scale = 0.01;

  global.renderer = new THREE.CanvasRenderer({
    canvas: $("canvas")[0]
  });

  global.scene = new THREE.Scene();

  global.camera = new THREE.OrthographicCamera(-window.global.width / 4, window.global.width / 4, -window.global.height / 4, window.global.height / 4, 1, 3000);

  global.camera.position.z = 1000;

  global.scene.add(global.camera);

  global.renderer.setSize(global.width, global.height);

  vertex = function(x, y, z) {
    if (z === void 0) {
      z = 0;
    }
    return new THREE.Vector3(x, y, z);
  };

  pushVertices = function(geometry, vertices) {
    var v, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = vertices.length; _i < _len; _i++) {
      v = vertices[_i];
      _results.push(geometry.vertices.push(v));
    }
    return _results;
  };

  face3 = function(a, b, c) {
    return new THREE.Face3(a, b, c);
  };

  face4 = function(a, b, c, d) {
    return new THREE.Face4(a, b, c, d);
  };

  pushFaces = function(geometry, faces) {
    var f, _i, _len, _results;
    _results = [];
    for (_i = 0, _len = faces.length; _i < _len; _i++) {
      f = faces[_i];
      _results.push(geometry.faces.push(f));
    }
    return _results;
  };

  atlas = THREE.ImageUtils.loadTexture("img/textures.png");

  atlas_w = 1022;

  atlas_h = 1520;

  vector2 = function(x, y) {
    return new THREE.Vector2(x, y);
  };

  jsonLoader = new THREE.JSONLoader();

  global.landerMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    transparent: true,
    side: THREE.DoubleSide,
    shading: THREE.FlatShading,
    map: atlas,
    overdraw: true
  });

  global.debugMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    wireframe: true,
    side: THREE.DoubleSide
  });

  terrainSurface = THREE.ImageUtils.loadTexture("img/lunarsurface.png");

  terrainSurface.wrapS = THREE.RepeatWrapping;

  terrainSurface.wrapT = THREE.RepeatWrapping;

  global.levelMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    side: THREE.DoubleSide,
    shading: THREE.FlatShading,
    overdraw: true,
    map: terrainSurface
  });

  zeroFill = function(i, n) {
    var a, j, _i, _ref;
    a = [];
    for (j = _i = 0, _ref = Math.floor(Math.log(i) / Math.log(10)) - n + 2; 0 <= _ref ? _i <= _ref : _i >= _ref; j = 0 <= _ref ? ++_i : --_i) {
      a.push("0");
    }
    return a.join("") + i;
  };

  countedCallback = function(func) {
    global.resourceCounter += 1;
    return function() {
      global.resourceCounter -= 1;
      func.apply(null, arguments);
      console.log("Resources left:", global.resourceCounter);
      if (global.resourceCounter === 0) {
        return launch();
      }
    };
  };

  landerFrameUvs = [];

  rocketFrameUvs = [];

  $.getJSON('js/textures.json', {}, countedCallback(function(data) {
    var array, frame, i, name, s, _i, _len, _ref, _ref1, _results;
    _ref = [["lander", landerFrameUvs], ["rocket", rocketFrameUvs]];
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _ref1 = _ref[_i], name = _ref1[0], array = _ref1[1];
      _results.push((function() {
        var _j, _results1;
        _results1 = [];
        for (i = _j = 1; _j <= 100; i = ++_j) {
          s = name + zeroFill(i, 4) + '.png';
          frame = data.frames[s].frame;
          _results1.push(array.push(vector2(frame.x / atlas_w, frame.y / atlas_h)));
        }
        return _results1;
      })());
    }
    return _results;
  }));

  Game = (function() {

    function Game() {
      this.mainLoop = __bind(this.mainLoop, this);

      this.keyUp = __bind(this.keyUp, this);

      this.keyDown = __bind(this.keyDown, this);

      var body, gravity, preventDefault,
        _this = this;
      gravity = new b2Vec2(0, 10 * b2Scale);
      this.world = new b2World(gravity, true);
      this.entities = [];
      this.lander = new Lander(this);
      body = $("body");
      preventDefault = function(func) {
        return function(event) {
          var r;
          r = func(event);
          event.preventDefault();
          return r;
        };
      };
      body.keydown(this.keyDown);
      body.keyup(this.keyUp);
      this.pressedKeys = {};
      new THREE.JSONLoader().load("js/level1.js", function(model) {
        var a, b, bone, count, countEdge, edge, edges, face, v1, v2, verts, x, y, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _results;
        _this.level = new THREE.Mesh(model, global.levelMaterial);
        global.scene.add(_this.level);
        _this.level.position.x = 0;
        _this.level.position.y = 0;
        _this.level.position.z = -1;
        _this.level.scale.y = -1;
        _this.level.scale.x = 1;
        verts = model.vertices;
        edges = {};
        countEdge = function(a, b) {
          var s, v;
          v = [a, b];
          v.sort();
          a = v[0], b = v[1];
          s = "" + a + "-" + b;
          return edges[s] = edges[s] != null ? edges[s] + 1 : 1;
        };
        _ref = model.faces;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          face = _ref[_i];
          countEdge(face.a, face.b);
          countEdge(face.b, face.c);
          countEdge(face.c, face.a);
        }
        for (edge in edges) {
          count = edges[edge];
          if (count === 1) {
            _ref1 = edge.split("-"), a = _ref1[0], b = _ref1[1];
            v1 = new b2Vec2(verts[a].x * b2Scale, -verts[a].y * b2Scale);
            v2 = new b2Vec2(verts[b].x * b2Scale, -verts[b].y * b2Scale);
            _this.makeEdge(v1, v2);
          }
        }
        _ref2 = model.bones;
        _results = [];
        for (_j = 0, _len1 = _ref2.length; _j < _len1; _j++) {
          bone = _ref2[_j];
          _ref3 = bone.pos, x = _ref3[0], y = _ref3[1];
          _results.push(new Rocket({
            game: _this,
            x: x,
            y: -y
          }));
        }
        return _results;
      });
      this.debugGeometry = new THREE.Geometry();
      this.debugMesh = new THREE.Mesh(this.debugGeometry, global.debugMaterial);
    }

    Game.prototype.keyDown = function(event) {
      return this.pressedKeys[event.keyCode] = true;
    };

    Game.prototype.keyUp = function(event) {
      return this.pressedKeys[event.keyCode] = false;
    };

    Game.prototype.mainLoop = function() {
      var dt, entity, newFrame, _i, _len, _ref;
      newFrame = new Date().getTime();
      dt = (newFrame - this.lastFrame) / 1000;
      if (dt > 2) {
        dt = 0.01;
      }
      this.lastFrame = newFrame;
      requestAnimationFrame(this.mainLoop);
      this.lander.steering = 0;
      if (this.pressedKeys[37]) {
        this.lander.steering = -1;
      }
      if (this.pressedKeys[39]) {
        this.lander.steering = 1;
      }
      this.lander.thrust = this.pressedKeys[38] ? 1 : 0;
      this.world.Step(dt, 5, 5);
      this.world.ClearForces();
      _ref = this.entities;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        entity = _ref[_i];
        entity.update(dt);
      }
      this.debugGeometry.vertices = [];
      this.debugGeometry.faces = [];
      pushVertices(this.debugGeometry, [vertex(0, 0, -1), vertex(100, 0, -1), vertex(0, 100, -1)]);
      pushFaces(this.debugGeometry, [face3(0, 1, 2)]);
      this.debugGeometry.verticesNeedUpdate = true;
      global.camera.position.x = this.lander.mesh.position.x;
      global.camera.position.y = this.lander.mesh.position.y;
      return global.renderer.render(global.scene, global.camera);
    };

    Game.prototype.launch = function() {
      this.lastFrame = new Date().getTime();
      return this.mainLoop();
    };

    Game.prototype.makeEdge = function(v1, v2) {
      var body, bodyDef, fixtureDef, shape;
      bodyDef = new b2BodyDef();
      bodyDef.type = b2Body.b2_staticBody;
      bodyDef.position.x = 0;
      bodyDef.position.y = 0;
      bodyDef.angle = 0;
      body = this.world.CreateBody(bodyDef);
      fixtureDef = new b2FixtureDef();
      fixtureDef.restitution = 0.0;
      fixtureDef.density = 2.0;
      fixtureDef.friction = 0.9;
      shape = new b2PolygonShape.AsEdge(v1, v2);
      fixtureDef.shape = shape;
      return body.CreateFixture(fixtureDef);
    };

    return Game;

  })();

  RotationalSprite = (function() {

    function RotationalSprite(config) {
      var body, bodyDef, fixtureDef, shape;
      this.game = config.game;
      this.game.entities.push(this);
      this.atlasUvs = config.atlasUvs;
      this.spriteW = config.spriteW;
      this.spriteH = config.spriteH;
      this.angleOffset = config.angleOffset;
      bodyDef = new b2BodyDef;
      this.bodyDef = bodyDef;
      bodyDef.type = b2Body.b2_dynamicBody;
      bodyDef.position.x = config.x * b2Scale;
      bodyDef.position.y = config.y * b2Scale;
      bodyDef.angle = 0;
      body = this.game.world.CreateBody(bodyDef);
      body.test = "test";
      this.body = body;
      body.w = config.width * b2Scale;
      body.h = config.height * b2Scale;
      fixtureDef = new b2FixtureDef;
      fixtureDef.restitution = 0.1;
      fixtureDef.density = config.mass / body.w / body.h;
      fixtureDef.friction = 0.7;
      shape = new b2PolygonShape.AsBox(body.w, body.h);
      fixtureDef.shape = shape;
      body.CreateFixture(fixtureDef);
      this.geometry = new THREE.PlaneGeometry(config.sideLength / 2, config.sideLength / 2, 1, 1);
      this.mesh = new THREE.Mesh(this.geometry, global.landerMaterial);
      global.scene.add(this.mesh);
      this.steering = 0;
    }

    RotationalSprite.prototype.setPosition = function(x, y) {
      return this.body.SetPosition(new b2Vec2(x, y));
    };

    RotationalSprite.prototype.update = function(dt) {
      var a, frame, v, x, y;
      x = this.body.GetPosition().x / b2Scale;
      y = this.body.GetPosition().y / b2Scale;
      this.mesh.position.x = x;
      this.mesh.position.y = y;
      a = this.body.GetAngle() + Math.PI / 2;
      if (this.atlasUvs.length > 0) {
        a = signedMod(a, Math.PI * 2);
        frame = signedMod(Math.floor((a / Math.PI / 2) * 100) + this.angleOffset, 100);
        v = this.atlasUvs[frame];
        this.geometry.faceVertexUvs = [[[vector2(v.x, 1 - v.y), vector2(v.x + this.spriteW, 1 - v.y), vector2(v.x + this.spriteW, 1 - v.y - this.spriteH), vector2(v.x, 1 - v.y - this.spriteH)]]];
        this.geometry.uvsNeedUpdate = true;
        return this.mesh.rotation.z = a - ((frame - this.angleOffset) / 100.0 * Math.PI * 2);
      }
    };

    return RotationalSprite;

  })();

  Lander = (function(_super) {

    __extends(Lander, _super);

    function Lander(game) {
      Lander.__super__.constructor.call(this, {
        game: game,
        atlasUvs: landerFrameUvs,
        width: 11,
        height: 6,
        mass: 1000000,
        spriteW: 64 / atlas_w,
        spriteH: 64 / atlas_h,
        x: 0,
        y: 0,
        angleOffset: 0,
        sideLength: 64
      });
    }

    Lander.prototype.update = function(dt) {
      var a, f, p1, thrust, x, y;
      x = this.body.GetPosition().x / b2Scale;
      y = this.body.GetPosition().y / b2Scale;
      a = this.body.GetAngle();
      this.body.m_torque = 2000000 * dt * this.steering;
      thrust = 80000000 * dt * this.thrust;
      f = new b2Vec2(thrust * Math.sin(a), -thrust * Math.cos(a));
      p1 = new b2Vec2(x * b2Scale, y * b2Scale);
      this.body.ApplyForce(f, p1);
      return Lander.__super__.update.call(this, dt);
    };

    return Lander;

  })(RotationalSprite);

  Rocket = (function(_super) {

    __extends(Rocket, _super);

    function Rocket(config) {
      config.game = config.game;
      config.atlasUvs = rocketFrameUvs;
      config.width = 7;
      config.height = 18;
      config.sideLength = 100;
      config.spriteW = 100 / atlas_w;
      config.spriteH = 100 / atlas_h;
      config.mass = 20000000;
      config.angleOffset = 0;
      Rocket.__super__.constructor.call(this, config);
      this.mesh.position.z = -1;
    }

    Rocket.prototype.update = function(dt) {
      return Rocket.__super__.update.call(this, dt);
    };

    return Rocket;

  })(RotationalSprite);

  launch = function() {
    var game;
    game = new Game();
    return game.launch();
  };

}).call(this);
