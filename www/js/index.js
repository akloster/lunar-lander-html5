// Generated by CoffeeScript 1.6.2
(function() {
  var body, entity, h, preventDefault, steps, v, w, _i, _len, _ref,
    _this = this;

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
      if (face.d != null) {
        countEdge(face.c, face.d);
        countEdge(face.d, face.a);
      } else {
        countEdge(face.c, face.a);
      }
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
        y: -y - 13
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
    var fixA, fixB, isContactBetween, maxVel, sumImpulses, vel, velocity;

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
    if (isContactBetween('terrain', 'landingGear') || isContactBetween('terrain', 'landerSphere')) {
      _this.lander.frameImpulse += sumImpulses(contact);
      vel = _this.lander.body.GetLinearVelocity();
      velocity = Math.sqrt(vel.x * vel.x + vel.y * vel.y);
      maxVel = 0.5;
      if (velocity > maxVel) {
        return _this.lander.damage += Math.max(10, (velocity - maxVel) / 10);
      }
    }
  };

  this.world.SetContactListener(this.listener);

  if (this.pressedKeys[39]) {
    this.lander.steering = 1;
  }

  this.lander.thrust = this.pressedKeys[38] ? 1 : 0;

  if (this.lander.destroyed) {
    this.lander.thrust = 0;
    this.lander.steering = 0;
  }

  this.lander.frameImpulse = 0;

  steps = dt * 60 * 60 * 5;

  this.world.Step(dt, steps, steps);

  this.world.ClearForces();

  _ref = this.entities;
  for (_i = 0, _len = _ref.length; _i < _len; _i++) {
    entity = _ref[_i];
    entity.update(dt);
  }

  if (this.lander.damage >= 100) {
    this.lander.damage = 100;
    if (this.lander.destroyed == null) {
      this.terminal.display("Houston, we have a problem...");
      this.terminal.display("The Lander is kaputt. Press 'r'");
      this.lander.destroyed = true;
    }
  }

  this.camera.position.x = this.lander.mesh.position.x;

  this.camera.position.y = this.lander.mesh.position.y;

  global.renderer.render(this.scene, this.camera);

  ctx.clearRect(0, 0, 200, 100);

  ctx.fillStyle = "#00ff22";

  ctx.font = "bold 12pt vt220";

  ctx.fillText("Fuel: " + (this.lander.fuel.toFixed(1)) + "s", 0, 15);

  ctx.fillText("Damage: " + (this.lander.damage.toFixed(1)) + "%", 0, 30);

  this.terminal.update(dt);

  this.terminal.draw();

  if (this.frameImpulse > 1500000) {
    this.damage += 5;
  }

  this.geometry = new THREE.PlaneGeometry(this.screenWidth / 2, this.screenHeight / 2, 1, 1);

  this.mesh = new THREE.Mesh(this.geometry, global.landerMaterial);

  this.game.scene.add(this.mesh);

  this.x = config.x;

  this.y = config.y;

  this.z = config.z;

  this.frame = 0;

  this.update(0.0001);

  v = this.atlasUvs[Math.floor(this.frame)];

  w = this.spriteW / atlas_w;

  h = this.spriteH / atlas_h;

  this.geometry.faceVertexUvs = [[[vector2(v.x, 1 - v.y), vector2(v.x + w, 1 - v.y), vector2(v.x + w, 1 - v.y - h), vector2(v.x, 1 - v.y - h)]]];

  this.geometry.uvsNeedUpdate = true;

}).call(this);
