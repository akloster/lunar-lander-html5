// Generated by CoffeeScript 1.6.2
(function() {
  var AnimatedSprite, Game, Lander, MissileBase, Rocket, RotationalSprite, Terminal, atlas, atlas_h, atlas_w, b2Scale, baseFrameUvs, countedCallback, ctx, exhaustFrameUvs, face3, face4, jsonLoader, landerFrameUvs, launch, pushFaces, pushVertices, rocketFrameUvs, terrainSurface, vector2, vertex, zeroFill,
    __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  window.global = {
    width: 1024,
    height: 600,
    resourceCounter: 0
  };

  window.signedMod = function(a, b) {
    if (a < 0) {
      return b + a % b;
    } else {
      return a % b;
    }
  };

  b2Scale = 0.01;

  global.renderer = new THREE.CanvasRenderer({
    canvas: $("canvas")[0]
  });

  global.renderer.setSize(global.width, global.height);

  ctx = $("canvas")[0].getContext('2d');

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

  atlas_w = 2048;

  atlas_h = 1058;

  vector2 = function(x, y) {
    return new THREE.Vector2(x, y);
  };

  jsonLoader = new THREE.JSONLoader();

  global.landerMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    transparent: true,
    side: THREE.DoubleSide,
    shading: THREE.FlatShading,
    transparency: true,
    map: atlas,
    overdraw: true,
    wireframe: true
  });

  global.exhaustMaterial = global.landerMaterial.clone();

  global.exhaustMaterial.opacity = 0.2;

  global.debugMaterial = new THREE.MeshBasicMaterial({
    color: 0xffffff,
    wireframe: true,
    shading: THREE.FlatShading,
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

  exhaustFrameUvs = [];

  baseFrameUvs = [];

  $.getJSON('js/textures.json', {}, countedCallback(function(data) {
    var array, frame, frames, i, name, s, _i, _len, _ref, _ref1, _results;

    _ref = [["lander", landerFrameUvs, 100], ["rocket", rocketFrameUvs, 100], ["exhaust", exhaustFrameUvs, 25], ["base", baseFrameUvs, 64]];
    _results = [];
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      _ref1 = _ref[_i], name = _ref1[0], array = _ref1[1], frames = _ref1[2];
      _results.push((function() {
        var _j, _results1;

        _results1 = [];
        for (i = _j = 1; 1 <= frames ? _j <= frames : _j >= frames; i = 1 <= frames ? ++_j : --_j) {
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
      var body, bodyDef, gravity, preventDefault,
        _this = this;

      gravity = new b2Vec2(0, 15 * b2Scale);
      this.quit = false;
      this.entities = [];
      this.bases = [];
      this.basesDestroyed = 0;
      this.world = new b2World(gravity, true);
      bodyDef = new b2BodyDef();
      bodyDef.type = b2Body.b2_staticBody;
      bodyDef.position.x = 0;
      bodyDef.position.y = 0;
      bodyDef.angle = 0;
      this.terrainBody = this.world.CreateBody(bodyDef);
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
      this.terminal = new Terminal();
      this.terminal.display("Destroy the missile bases by landing on them...");
      this.scene = new THREE.Scene();
      this.camera = new THREE.OrthographicCamera(-window.global.width / 4, window.global.width / 4, -window.global.height / 4, window.global.height / 4, -10, 3000);
      this.camera.position.z = 1000;
      this.scene.add(this.camera);
      this.lander = new Lander(this);
      new THREE.JSONLoader().load("js/level1.js", function(model) {
        var a, b, bone, count, countEdge, edge, edges, face, v1, v2, verts, x, y, _i, _j, _len, _len1, _ref, _ref1, _ref2, _ref3, _results;

        _this.level = new THREE.Mesh(model, global.levelMaterial);
        _this.scene.add(_this.level);
        _this.level.position.x = 0;
        _this.level.position.y = 0;
        _this.level.position.z = -4;
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
          new Rocket({
            game: _this,
            x: x,
            y: -y - 10
          });
          _results.push(new MissileBase({
            game: _this,
            x: x,
            y: -y
          }));
        }
        return _results;
      });
      this.listener = new b2ContactListener();
      this.listener.PostSolve = function(contact, impulse) {
        var fixA, fixB, isContactBetween, sumImpulses, totalImpulse;

        fixA = contact.GetFixtureA();
        fixB = contact.GetFixtureB();
        isContactBetween = function(id1, id2) {
          return ((fixA.m_userData === id1) && (fixB.m_userData === id2)) || ((fixA.m_userData === id2) && (fixB.m_userData === id1));
        };
        sumImpulses = function(contact) {
          var point, points, totalImpulse, _i, _len;

          points = contact.GetManifold().m_points;
          totalImpulse = 0;
          for (_i = 0, _len = points.length; _i < _len; _i++) {
            point = points[_i];
            totalImpulse += point.m_normalImpulse;
          }
          return totalImpulse;
        };
        if (isContactBetween('terrain', 'landingGear')) {
          return totalImpulse = sumImpulses(contact);
        }
      };
      this.world.SetContactListener(this.listener);
    }

    Game.prototype.keyDown = function(event) {
      var code, _i, _len, _ref, _results;

      this.pressedKeys[event.keyCode] = true;
      _ref = [37, 38, 39];
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        code = _ref[_i];
        if (event.keyCode === code) {
          _results.push(event.preventDefault());
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    };

    Game.prototype.keyUp = function(event) {
      return this.pressedKeys[event.keyCode] = false;
    };

    Game.prototype.mainLoop = function(newFrame) {
      var dt, entity, game, _i, _len, _ref;

      if (newFrame != null) {
        dt = (newFrame - this.lastFrame) / 1000;
        if (dt > 2) {
          dt = 0.01;
        }
        if ((dt === 0) || isNaN(dt)) {
          dt = 0.0001;
        }
      } else {
        dt = 0.0001;
      }
      this.lastFrame = newFrame;
      if (this.pressedKeys[82]) {
        this.quit = true;
      }
      if (this.quit) {
        game = new Game();
        game.launch();
      } else {
        requestAnimationFrame(this.mainLoop);
      }
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
      this.camera.position.x = this.lander.mesh.position.x;
      this.camera.position.y = this.lander.mesh.position.y;
      global.renderer.render(this.scene, this.camera);
      ctx.clearRect(0, 0, 200, 100);
      ctx.fillStyle = "#00ff22";
      ctx.font = "bold 12pt vt220";
      ctx.fillText("Fuel: " + (this.lander.fuel.toFixed(1)) + "s", 0, 15);
      this.terminal.update(dt);
      return this.terminal.draw();
    };

    Game.prototype.launch = function() {
      this.lastFrame = new Date().getTime();
      return this.mainLoop();
    };

    Game.prototype.makeEdge = function(v1, v2) {
      var fixtureDef, shape;

      fixtureDef = new b2FixtureDef();
      fixtureDef.restitution = 0.1;
      fixtureDef.density = 2.0;
      fixtureDef.friction = 0.7;
      fixtureDef.userData = "terrain";
      shape = new b2PolygonShape.AsEdge(v1, v2);
      fixtureDef.shape = shape;
      return this.terrainBody.CreateFixture(fixtureDef);
    };

    return Game;

  })();

  RotationalSprite = (function() {
    function RotationalSprite(config) {
      this.game = config.game;
      this.game.entities.push(this);
      this.atlasUvs = config.atlasUvs;
      this.spriteW = config.spriteW;
      this.spriteH = config.spriteH;
      this.angleOffset = config.angleOffset;
      this.createBody(config);
      this.geometry = new THREE.PlaneGeometry(config.sideLength / 2, config.sideLength / 2, 1, 1);
      this.mesh = new THREE.Mesh(this.geometry, global.landerMaterial);
      this.game.scene.add(this.mesh);
      this.steering = 0;
    }

    RotationalSprite.prototype.createBody = function() {
      return void 0;
    };

    RotationalSprite.prototype.setPosition = function(x, y) {
      return this.body.SetPosition(new b2Vec2(x, y));
    };

    RotationalSprite.prototype.update = function(dt) {
      var a, frame, v, x, y;

      x = this.body.GetPosition().x / b2Scale;
      y = this.body.GetPosition().y / b2Scale;
      this.mesh.position.x = x;
      this.mesh.position.y = y;
      this.mesh.position.z = -1;
      a = this.body.GetAngle() + Math.PI / 2;
      if (this.atlasUvs.length > 0) {
        a = signedMod(a, Math.PI * 2);
        frame = Math.floor(signedMod(a / Math.PI / 2 * 99 + this.angleOffset, 100));
        v = this.atlasUvs[frame];
        this.geometry.faceVertexUvs = [[[vector2(v.x, 1 - v.y), vector2(v.x + this.spriteW, 1 - v.y), vector2(v.x + this.spriteW, 1 - v.y - this.spriteH), vector2(v.x, 1 - v.y - this.spriteH)]]];
        this.geometry.uvsNeedUpdate = true;
        return this.mesh.rotation.z = a - ((frame - this.angleOffset) / 99.0 * Math.PI * 2);
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
        width: 9,
        height: 2,
        mass: 1000000,
        spriteW: 64 / atlas_w,
        spriteH: 64 / atlas_h,
        x: 0,
        y: 0,
        angleOffset: 0,
        sideLength: 64,
        friction: 0.2
      });
      this.fuel = 25;
      this.exhaustGeometry = new THREE.PlaneGeometry(32, 32, 1, 1);
      this.exhaustMesh = new THREE.Mesh(this.exhaustGeometry, global.exhaustMaterial);
      this.exhaustStrength = 0;
      this.exhaustCycle = 0;
      this.game.scene.add(this.exhaustMesh);
    }

    Lander.prototype.createBody = function(config) {
      var body, bodyDef, fixtureDef;

      bodyDef = new b2BodyDef;
      this.bodyDef = bodyDef;
      bodyDef.type = b2Body.b2_dynamicBody;
      bodyDef.position.x = config.x * b2Scale;
      bodyDef.position.y = config.y * b2Scale;
      bodyDef.angle = 0.01;
      body = this.game.world.CreateBody(bodyDef);
      body.test = "test";
      this.body = body;
      body.w = config.width * b2Scale;
      body.h = config.height * b2Scale;
      fixtureDef = new b2FixtureDef;
      fixtureDef.restitution = 0.1;
      fixtureDef.density = config.mass / body.w / body.h;
      fixtureDef.friction = config.friction;
      fixtureDef.shape = new b2PolygonShape.AsOrientedBox(body.w, body.h, new b2Vec2(0, 4 * b2Scale), 0);
      fixtureDef.userData = "landingGear";
      body.CreateFixture(fixtureDef);
      fixtureDef = new b2FixtureDef;
      fixtureDef.restitution = 0.1;
      fixtureDef.density = config.mass / body.w / body.h;
      fixtureDef.friction = 0.4;
      fixtureDef.shape = new b2CircleShape(4 * b2Scale);
      fixtureDef.shape.SetLocalPosition(new b2Vec2(0, -5 * b2Scale));
      fixtureDef.userData = "landerSphere";
      return body.CreateFixture(fixtureDef);
    };

    Lander.prototype.update = function(dt) {
      var a, f, frame, h, p1, thrust, v, vel, w, x, y;

      x = this.body.GetPosition().x / b2Scale;
      y = this.body.GetPosition().y / b2Scale;
      a = this.body.GetAngle();
      vel = this.game.lander.body.GetLinearVelocity();
      this.velD = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
      this.vel = vel;
      this.body.m_torque = 2000000 * dt * this.steering;
      this.fuel -= (this.thrust ? 1 : 0) * dt;
      this.fuel = Math.max(0, this.fuel);
      if (this.fuel === 0) {
        if (this.outOfFuel == null) {
          this.outOfFuel = true;
          this.game.terminal.display("Out of Fuel. Press 'r' to retry ...");
        }
        this.thrust = 0;
      }
      this.exhaustStrength += (this.thrust ? 1 : -1) * 5 * dt;
      this.exhaustStrength = Math.min(Math.max(this.exhaustStrength, 0), 1);
      global.exhaustMaterial.opacity = this.exhaustStrength;
      thrust = 80000000 * dt * this.thrust;
      f = new b2Vec2(thrust * Math.sin(a), -thrust * Math.cos(a));
      p1 = new b2Vec2(x * b2Scale, y * b2Scale);
      this.body.ApplyForce(f, p1);
      Lander.__super__.update.call(this, dt);
      this.exhaustCycle += dt * 15;
      this.exhaustCycle %= 25;
      frame = Math.floor(this.exhaustCycle);
      v = exhaustFrameUvs[frame];
      w = 64 / atlas_w;
      h = 64 / atlas_h;
      this.exhaustGeometry.faceVertexUvs = [[[vector2(v.x, 1 - v.y), vector2(v.x + w, 1 - v.y), vector2(v.x + w, 1 - v.y - h), vector2(v.x, 1 - v.y - h)]]];
      this.exhaustGeometry.uvsNeedUpdate = true;
      this.exhaustMesh.position.x = x;
      this.exhaustMesh.position.y = y;
      this.exhaustMesh.position.z = -1;
      return this.exhaustMesh.rotation.z = a + Math.PI / 2;
    };

    return Lander;

  })(RotationalSprite);

  Rocket = (function(_super) {
    __extends(Rocket, _super);

    function Rocket(config) {
      this.update = __bind(this.update, this);      config.game = config.game;
      config.atlasUvs = rocketFrameUvs;
      config.width = 2.6;
      config.height = 15;
      config.sideLength = 100;
      config.spriteW = 100 / atlas_w;
      config.spriteH = 100 / atlas_h;
      config.friction = 0.1;
      config.mass = 10000000;
      config.angleOffset = 0;
      Rocket.__super__.constructor.call(this, config);
      this.mesh.position.z = -1;
    }

    Rocket.prototype.createBody = function(config) {
      var body, bodyDef, fixtureDef, shape;

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
      fixtureDef.friction = config.friction;
      shape = new b2PolygonShape.AsBox(body.w, body.h);
      fixtureDef.shape = shape;
      return body.CreateFixture(fixtureDef);
    };

    Rocket.prototype.update = function(dt) {
      return Rocket.__super__.update.call(this, dt);
    };

    return Rocket;

  })(RotationalSprite);

  AnimatedSprite = (function() {
    function AnimatedSprite(config) {
      this.game = config.game;
      this.game.entities.push(this);
      this.atlasUvs = config.atlasUvs;
      this.spriteW = config.spriteW;
      this.spriteH = config.spriteH;
      this.screenWidth = config.screenWidth;
      this.screenHeight = config.screenHeight;
      this.geometry = new THREE.PlaneGeometry(this.screenWidth / 2, this.screenHeight / 2, 1, 1);
      this.mesh = new THREE.Mesh(this.geometry, global.landerMaterial);
      this.game.scene.add(this.mesh);
      this.x = config.x;
      this.y = config.y;
      this.z = config.z;
      this.frame = 0;
      this.update(0.0001);
    }

    AnimatedSprite.prototype.update = function(dt) {
      var h, v, w;

      this.mesh.position.x = this.x;
      this.mesh.position.y = this.y;
      this.mesh.position.z = this.z;
      this.mesh.rotation.z = Math.PI / 2;
      v = this.atlasUvs[Math.floor(this.frame)];
      w = this.spriteW / atlas_w;
      h = this.spriteH / atlas_h;
      this.geometry.faceVertexUvs = [[[vector2(v.x, 1 - v.y), vector2(v.x + w, 1 - v.y), vector2(v.x + w, 1 - v.y - h), vector2(v.x, 1 - v.y - h)]]];
      return this.geometry.uvsNeedUpdate = true;
    };

    return AnimatedSprite;

  })();

  MissileBase = (function(_super) {
    __extends(MissileBase, _super);

    function MissileBase(config) {
      this.update = __bind(this.update, this);      this.exploded = false;
      MissileBase.__super__.constructor.call(this, {
        game: config.game,
        x: config.x,
        y: config.y - 5,
        z: -2,
        spriteW: 80,
        spriteH: 80,
        screenWidth: 80,
        screenHeight: 80,
        atlasUvs: baseFrameUvs
      });
      this.game.bases.push(this);
    }

    MissileBase.prototype.update = function(dt) {
      var print,
        _this = this;

      if (this.exploded) {
        this.frame += dt * 15;
        this.frame = Math.min(this.frame, 63);
      }
      MissileBase.__super__.update.call(this, dt);
      if (this.game.lander.velD < 0.01) {
        if (Math.abs(this.x - this.game.lander.mesh.position.x) < 5) {
          if (Math.abs(this.y - this.game.lander.mesh.position.y - 5) < 15) {
            if (Math.abs(this.game.lander.body.GetAngle()) < Math.PI / 360 * 10) {
              if (!this.exploded) {
                this.game.basesDestroyed += 1;
                this.exploded = true;
                this.game.lander.fuel = 20;
                print = function(s) {
                  return _this.game.terminal.display(s);
                };
                switch (this.game.basesDestroyed) {
                  case 1:
                    return print("The eagle has landed...");
                  case 2:
                    print("One small step for man...");
                    return print("One huge BOOM for mankind...");
                }
              }
            }
          }
        }
      }
    };

    return MissileBase;

  })(AnimatedSprite);

  Terminal = (function() {
    function Terminal() {
      this.display = __bind(this.display, this);      this.queuedLines = [];
      this.displayedLines = [];
      this.column = 0;
      this.ctx = $("canvas#terminal")[0].getContext('2d');
      this.removalTime = 0;
    }

    Terminal.prototype.update = function(dt) {
      var currentLineWidth, line;

      if (this.displayedLines.length > 0) {
        this.column += dt * 15;
        currentLineWidth = this.displayedLines[this.displayedLines.length - 1].length;
        this.removalTime += dt;
        if (this.removalTime > 100) {
          line = this.displayedLines.shift();
          if (this.displayedLines.length === 1) {
            this.column = this.displayedLines[0].length + 1;
          }
          this.removalTime = 0;
        }
      } else {
        currentLineWidth = -1;
        this.removalTime = 0;
      }
      if (this.column > currentLineWidth) {
        this.column = currentLineWidth;
        if (this.queuedLines.length > 0) {
          line = this.queuedLines.shift();
          this.displayedLines.push(line);
          return this.column = 0;
        }
      }
    };

    Terminal.prototype.display = function(line) {
      console.log(line);
      return this.queuedLines.push(line);
    };

    Terminal.prototype.draw = function() {
      var i, lineH, numLines, y, _i, _ref, _ref1;

      this.ctx.clearRect(0, 0, 500, 500);
      this.ctx.fillStyle = "#00ff22";
      this.ctx.font = "bold 12pt vt220";
      numLines = this.displayedLines.length;
      y = 0;
      lineH = 15;
      if (numLines > 1) {
        for (i = _i = _ref = Math.max(0, numLines - 5), _ref1 = Math.max(0, numLines - 2); _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; i = _ref <= _ref1 ? ++_i : --_i) {
          this.ctx.fillText(this.displayedLines[i], 0, y + lineH);
          y += lineH;
        }
      }
      if (numLines > 0) {
        return this.ctx.fillText(this.displayedLines[numLines - 1].substr(0, Math.round(this.column)), 0, y + lineH);
      }
    };

    return Terminal;

  })();

  launch = function() {
    var game;

    game = new Game();
    return game.launch();
  };

}).call(this);
