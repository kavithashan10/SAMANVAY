/* SAMANVAY · 3D underground cutaway.
 *
 * Draws one stretch of road at the Manaparai Bus Stand demo site with the
 * ground opened up, from the sample utility records the app sends in
 * window.samanvayLoad(data). Everything is generated on the device: no
 * network, no model files. Sizes and depths are drawn larger than life so the
 * network reads on a phone; the scale factors are shown on screen.
 *
 * Axes: x = across the road (metres, + to the right looking along the road),
 * y = up, z = along the road (0 at the cut face, negative away from viewer).
 */
(function () {
  'use strict';
  const T = THREE;
  const bridge = (msg) => { try { window.Samanvay && window.Samanvay.postMessage(JSON.stringify(msg)); } catch (e) {} };

  // ------------------------------------------------------------------ colours
  const KIND = {
    water:       { color: 0x3E8FD1, name: 'Drinking water',      text: 'WATER MAIN', tag: 'Water main' },
    sewer:       { color: 0x5E86C2, name: 'Sewerage',            text: 'SEWER', tag: 'Sewer' },
    storm:       { color: 0xC9CBC6, name: 'Stormwater drainage', text: 'STORM DRAIN', tag: 'Storm drain' },
    electricity: { color: 0xD8432F, name: 'Electricity',         text: 'POWER CABLE', tag: 'Power ducts' },
    gas:         { color: 0xE8BE1E, name: 'Gas',                 text: 'GAS', tag: 'Gas line' },
    telecom:     { color: 0xE8C220, name: 'Telecom ducts',       text: 'TELECOM', tag: 'Telecom ducts' },
    fibre:       { color: 0x9AA0A6, name: 'Optical fibre',       text: 'FIBRE', tag: 'Optical fibre' },
  };

  // ------------------------------------------------------------------ renderer
  const canvas = document.getElementById('gl');
  const renderer = new T.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = T.sRGBEncoding;
  renderer.toneMapping = T.NoToneMapping;
  renderer.toneMappingExposure = 1;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.PCFSoftShadowMap;
  const maxAniso = renderer.capabilities.getMaxAnisotropy();

  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(42, 1, 0.3, 900);

  // ------------------------------------------------------------------ helpers
  function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }
  function tex(w, h, draw, repeatX = 1, repeatY = 1, srgb = true) {
    const c = document.createElement('canvas'); c.width = w; c.height = h;
    draw(c.getContext('2d'), w, h);
    const t = new T.CanvasTexture(c);
    t.wrapS = t.wrapT = T.RepeatWrapping; t.repeat.set(repeatX, repeatY);
    t.anisotropy = maxAniso; if (srgb) t.encoding = T.sRGBEncoding;
    return t;
  }
  function speckle(g, w, h, n, colors, rmin, rmax, seed) {
    const r = rng(seed);
    for (let i = 0; i < n; i++) {
      g.fillStyle = colors[(r() * colors.length) | 0];
      const s = rmin + r() * (rmax - rmin);
      g.fillRect(r() * w, r() * h, s, s);
    }
  }
  function stones(g, w, h, n, colors, rmin, rmax, seed) {
    const r = rng(seed);
    for (let i = 0; i < n; i++) {
      const x = r() * w, y = r() * h, rx = rmin + r() * (rmax - rmin), ry = rx * (0.45 + r() * 0.35);
      g.fillStyle = colors[(r() * colors.length) | 0];
      g.beginPath(); g.ellipse(x, y, rx, ry, r() * Math.PI, 0, Math.PI * 2); g.fill();
      g.fillStyle = 'rgba(255,255,255,.12)';
      g.beginPath(); g.ellipse(x - rx * .25, y - ry * .3, rx * .45, ry * .35, 0, 0, Math.PI * 2); g.fill();
    }
  }

  // Textures (metre-based repeats are set per mesh via repeat).
  const asphaltTex = tex(512, 512, (g, w, h) => {
    g.fillStyle = '#3E4349'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 26000, ['#2F3338', '#4B5057', '#565B62', '#383C41', '#62676E'], 1, 2.6, 3);
    const r = rng(9);
    for (let i = 0; i < 14; i++) { g.fillStyle = `rgba(0,0,0,${0.04 + r() * 0.06})`; g.beginPath(); g.ellipse(r() * w, r() * h, 30 + r() * 90, 18 + r() * 50, r() * 3, 0, 7); g.fill(); }
  });
  const concreteTex = tex(512, 512, (g, w, h) => {
    g.fillStyle = '#9C9F9D'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 18000, ['#8C8F8D', '#AAADAB', '#818482', '#B3B6B4'], 1, 2.2, 5);
    g.strokeStyle = 'rgba(0,0,0,.12)'; g.lineWidth = 2;
    for (let x = 0; x <= w; x += 128) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); }
  });
  const gravelTex = tex(256, 256, (g, w, h) => {
    g.fillStyle = '#9A958A'; g.fillRect(0, 0, w, h);
    stones(g, w, h, 900, ['#B4AEA2', '#857F75', '#A7A196', '#C6C0B4', '#6F6A62'], 2, 6, 7);
  });
  const soilTex = tex(512, 1024, (g, w, h) => {
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#5E432D'); grad.addColorStop(.18, '#6E5036'); grad.addColorStop(.2, '#8C6A47');
    grad.addColorStop(.55, '#9A7550'); grad.addColorStop(.57, '#7B5C3F'); grad.addColorStop(1, '#6A4E36');
    g.fillStyle = grad; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 30000, ['rgba(40,25,12,.35)', 'rgba(255,235,200,.12)', 'rgba(60,40,20,.25)'], 1, 3, 11);
    const r = rng(13);
    for (let i = 0; i < 70; i++) { g.strokeStyle = `rgba(40,25,12,${.08 + r() * .14})`; g.lineWidth = 1 + r() * 3; g.beginPath(); const y = r() * h; g.moveTo(0, y); g.bezierCurveTo(w * .3, y + (r() - .5) * 30, w * .7, y + (r() - .5) * 30, w, y + (r() - .5) * 20); g.stroke(); }
    stones(g, w, h, 160, ['#8E857A', '#6F675E', '#A39A8E'], 2, 7, 17);
  });
  const floorTex = tex(512, 512, (g, w, h) => {
    g.fillStyle = '#6E5238'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 26000, ['rgba(35,22,10,.35)', 'rgba(255,230,190,.10)', 'rgba(90,65,40,.4)'], 1, 3, 37);
    stones(g, w, h, 220, ['#8E857A', '#6F675E', '#A39A8E', '#7B5C3F'], 2, 7, 39);
    const r = rng(41);
    for (let i = 0; i < 30; i++) { g.fillStyle = `rgba(30,18,8,${.06 + r() * .08})`; g.beginPath(); g.ellipse(r() * w, r() * h, 20 + r() * 60, 10 + r() * 30, r() * 3, 0, 7); g.fill(); }
  });
  const rockTex = tex(512, 512, (g, w, h) => {
    const grad = g.createLinearGradient(0, 0, 0, h);
    grad.addColorStop(0, '#7A5A3C'); grad.addColorStop(.22, '#7A5A3C'); grad.addColorStop(.24, '#8E857A');
    grad.addColorStop(.6, '#7A7166'); grad.addColorStop(.62, '#625A51'); grad.addColorStop(1, '#4E4842');
    g.fillStyle = grad; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 24000, ['rgba(0,0,0,.2)', 'rgba(255,255,255,.1)'], 1, 2.5, 19);
    stones(g, w, h * .2, 60, ['#5E4430', '#8E6B4A'], 2, 6, 23);
    const r = rng(29);
    for (let i = 0; i < 260; i++) {
      const x = r() * w, y = h * .24 + r() * h * .76, rx = 4 + r() * 16, ry = rx * (.4 + r() * .35);
      g.fillStyle = ['#A39A8E', '#7D746A', '#B7AEA2', '#6A625A', '#938A7E'][(r() * 5) | 0];
      g.beginPath(); g.ellipse(x, y, rx, ry, r() * 3, 0, 7); g.fill();
      g.strokeStyle = 'rgba(0,0,0,.25)'; g.lineWidth = 1; g.stroke();
    }
  });
  const grassTex = tex(256, 256, (g, w, h) => {
    g.fillStyle = '#6F8F52'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 12000, ['#5E7E44', '#86A464', '#7A9858', '#55733D'], 1, 2.5, 31);
  });
  function aerialTex(seed) {
    return tex(1024, 1024, (g, w, h) => {
      g.fillStyle = '#7E9468'; g.fillRect(0, 0, w, h);
      const r = rng(seed);
      for (let i = 0; i < 260; i++) { g.fillStyle = ['rgba(90,110,70,.5)', 'rgba(150,140,110,.45)', 'rgba(110,130,85,.5)', 'rgba(170,160,130,.35)'][(r() * 4) | 0];
        g.beginPath(); g.ellipse(r() * w, r() * h, 20 + r() * 80, 10 + r() * 50, r() * 3, 0, 7); g.fill(); }
      // building roofs
      for (let i = 0; i < 120; i++) {
        const x = r() * w, y = r() * h, bw = 20 + r() * 46, bh = 18 + r() * 40;
        g.fillStyle = ['#B9B4AA', '#A8A39A', '#C9C2B5', '#9EA3A6', '#B7A895', '#D2CBBE', '#8F948F'][(r() * 7) | 0];
        g.fillRect(x, y, bw, bh); g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(x, y + bh * .5, bw, bh * .5);
      }
      // parcel lines (GIS layer look)
      g.strokeStyle = 'rgba(240,220,80,.85)'; g.lineWidth = 2.2;
      for (let x = 0; x <= w; x += 128) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, h); g.stroke(); }
      for (let y = 0; y <= h; y += 96) { g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke(); }
    });
  }
  function strataTexture(FLOOR, BASE) {
    // Topsoil, clay, weathered rock and hard rock, proportioned to this cut's depth.
    return tex(512, 2048, (g, w, h) => {
      const at = (y) => y / BASE * h;           // y (negative metres) -> pixel row
      const bands = [[0, -1.4, '#5C422C'], [-1.4, FLOOR * .55, '#8E6A47'], [FLOOR * .55, FLOOR - 1, '#7A5B3E'],
                     [FLOOR - 1, FLOOR - 5, '#8B8277'], [FLOOR - 5, FLOOR - 10, '#6F665C'], [FLOOR - 10, BASE, '#575049']];
      for (const [a, b, c] of bands) { g.fillStyle = c; g.fillRect(0, at(a), w, at(b) - at(a) + 1); }
      speckle(g, w, h, 60000, ['rgba(0,0,0,.22)', 'rgba(255,240,220,.10)', 'rgba(40,25,12,.25)'], 1, 3, 51);
      const r = rng(53);
      for (let i = 0; i < 120; i++) { g.strokeStyle = `rgba(30,18,8,${.08 + r() * .12})`; g.lineWidth = 1 + r() * 2.5; const y = r() * at(FLOOR - 1);
        g.beginPath(); g.moveTo(0, y); g.bezierCurveTo(w * .3, y + (r() - .5) * 26, w * .7, y + (r() - .5) * 26, w, y + (r() - .5) * 18); g.stroke(); }
      for (let i = 0; i < 900; i++) {
        const y = at(FLOOR - 1) + r() * (h - at(FLOOR - 1)), x = r() * w, rx = 4 + r() * 15, ry = rx * (.4 + r() * .35);
        g.fillStyle = ['#A39A8E', '#7D746A', '#B7AEA2', '#6A625A', '#938A7E', '#5E574F'][(r() * 6) | 0];
        g.beginPath(); g.ellipse(x, y, rx, ry, r() * 3, 0, 7); g.fill();
        g.strokeStyle = 'rgba(0,0,0,.28)'; g.lineWidth = 1; g.stroke();
        g.fillStyle = 'rgba(255,255,255,.12)'; g.beginPath(); g.ellipse(x - rx * .25, y - ry * .3, rx * .4, ry * .3, 0, 0, 7); g.fill();
      }
      stones(g, w, at(FLOOR - 1), 140, ['#8E857A', '#6F675E', '#A39A8E'], 2, 6, 57);
    }, 3, 1);
  }
  function labelTexture(text, base, along) {
    // Text that runs along a pipe: canvas height maps to the pipe length.
    return tex(256, 1024, (g, w, h) => {
      g.fillStyle = base; g.fillRect(0, 0, w, h);
      g.fillStyle = 'rgba(255,255,255,.08)'; g.fillRect(0, 0, w, h * .02);
      for (const u of [.125, .375, .625, .875]) {
        g.save(); g.translate(w * u, h / 2); g.rotate(-Math.PI / 2);
        g.font = 'bold 22px Roboto, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
        g.fillStyle = 'rgba(255,255,255,.85)'; g.fillText(text, 0, 0);
        g.restore();
      }
    }, 1, along);
  }
  function hex(c) { return '#' + c.toString(16).padStart(6, '0'); }

  // ------------------------------------------------------------------ environment
  function buildEnvironment() {
    const envScene = new T.Scene();
    const geo = new T.SphereGeometry(50, 32, 16);
    const cols = [];
    const top = new T.Color(0xBFD6EA), mid = new T.Color(0xF2EEE6), low = new T.Color(0x7A6A55);
    const pos = geo.attributes.position;
    for (let i = 0; i < pos.count; i++) {
      const y = pos.getY(i) / 50;
      const c = y > 0 ? mid.clone().lerp(top, y) : mid.clone().lerp(low, -y);
      cols.push(c.r, c.g, c.b);
    }
    geo.setAttribute('color', new T.Float32BufferAttribute(cols, 3));
    envScene.add(new T.Mesh(geo, new T.MeshBasicMaterial({ vertexColors: true, side: T.BackSide })));
    const pm = new T.PMREMGenerator(renderer);
    envMap = pm.fromScene(envScene, 0.04).texture;
    const sky = tex(4, 512, (g, w, h) => {
      const gr = g.createLinearGradient(0, 0, 0, h);
      gr.addColorStop(0, '#9FC2DE'); gr.addColorStop(.55, '#DCE8EE'); gr.addColorStop(1, '#EEF0EA');
      g.fillStyle = gr; g.fillRect(0, 0, w, h);
    });
    sky.wrapS = sky.wrapT = T.ClampToEdgeWrapping; sky.repeat.set(1, 1);
    scene.background = sky;
    scene.fog = new T.Fog(0xDDE6E9, 160, 460);

    scene.add(new T.HemisphereLight(0xDCE8F2, 0x5A4A38, 0.5));
    const sun = new T.DirectionalLight(0xFFF0DA, 0.95);
    sun.position.set(-28, 46, 22);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    const sc = sun.shadow.camera; sc.left = -45; sc.right = 45; sc.top = 45; sc.bottom = -60; sc.near = 1; sc.far = 160;
    sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.03;
    sun.target.position.set(0, -4, -18);
    scene.add(sun, sun.target);
  }

  // ------------------------------------------------------------------ extra textures
  const tileTex = tex(256, 256, (g, w, h) => {
    g.fillStyle = '#CFC7B8'; g.fillRect(0, 0, w, h);
    speckle(g, w, h, 5000, ['#C3BBAC', '#D9D2C4', '#BDB5A6'], 1, 2, 61);
    g.strokeStyle = 'rgba(90,80,64,.35)'; g.lineWidth = 2;
    for (let i = 0; i <= 4; i++) { g.beginPath(); g.moveTo(i * 64, 0); g.lineTo(i * 64, h); g.stroke(); g.beginPath(); g.moveTo(0, i * 64); g.lineTo(w, i * 64); g.stroke(); }
  });
  const townTex = tex(512, 512, (g, w, h) => {
    g.fillStyle = '#86986C'; g.fillRect(0, 0, w, h);
    const r = rng(71);
    for (let i = 0; i < 160; i++) { g.fillStyle = ['rgba(95,115,72,.55)', 'rgba(160,148,115,.45)', 'rgba(118,138,90,.5)', 'rgba(176,162,128,.35)'][(r() * 4) | 0];
      g.beginPath(); g.ellipse(r() * w, r() * h, 12 + r() * 50, 8 + r() * 30, r() * 3, 0, 7); g.fill(); }
    speckle(g, w, h, 9000, ['rgba(60,80,40,.35)', 'rgba(200,190,160,.2)'], 1, 2.5, 73);
  });
  const busSideTex = tex(512, 128, (g, w, h) => {
    g.fillStyle = '#F4F4F2'; g.fillRect(0, 0, w, h);
    g.fillStyle = 'rgba(0,0,0,.18)'; g.fillRect(0, h * .78, w, h * .22);
    g.fillStyle = '#1C2630'; g.fillRect(w * .04, h * .2, w * .92, h * .34);
    g.fillStyle = 'rgba(255,255,255,.35)';
    for (let x = w * .04; x < w * .96; x += w * .092) g.fillRect(x, h * .2, 3, h * .34);
    g.fillStyle = '#1C2630'; g.fillRect(w * .8, h * .2, w * .07, h * .58);
    g.fillStyle = 'rgba(255,255,255,.75)'; g.fillRect(0, h * .6, w, h * .05);
  });
  const busEndTex = tex(128, 128, (g, w, h) => {
    g.fillStyle = '#F4F4F2'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#1C2630'; g.fillRect(w * .08, h * .12, w * .84, h * .42);
    g.fillStyle = '#F2C230'; g.fillRect(w * .08, h * .68, w * .18, h * .08); g.fillRect(w * .74, h * .68, w * .18, h * .08);
  });
  function signTex(text, bg, fg, w = 512, h = 128) {
    return tex(w, h, (g) => {
      g.fillStyle = bg; g.fillRect(0, 0, w, h);
      g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 6; g.strokeRect(8, 8, w - 16, h - 16);
      g.fillStyle = fg; g.font = `bold ${Math.round(h * .42)}px Roboto, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillText(text, w / 2, h / 2 + 2, w - 40);
    });
  }
  const glowTex = tex(64, 64, (g, w, h) => {
    const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(.35, 'rgba(255,255,255,.55)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  }, 1, 1, false);
  const scanTex = tex(256, 8, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, 0);
    gr.addColorStop(0, 'rgba(120,220,255,0)'); gr.addColorStop(.86, 'rgba(120,220,255,.28)'); gr.addColorStop(.97, 'rgba(210,245,255,.95)'); gr.addColorStop(1, 'rgba(210,245,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  }, 1, 1, false);
  [glowTex, scanTex].forEach((t) => { t.wrapS = t.wrapT = T.ClampToEdgeWrapping; });

  // ------------------------------------------------------------------ scene state
  let envMap = null;
  let root = null;
  const pickables = [];         // meshes that can be tapped
  const anchors = [];           // { pos: Vector3, el, kind, id }
  const fx = [];                // per-frame effects: (dt, t) => void
  let data = null;
  let selectedId = null;
  let builtAt = 0;

  function mat(opts) { return new T.MeshStandardMaterial(Object.assign({ roughness: .85, metalness: 0 }, opts)); }
  function repeatClone(t, rx, ry) { const c = t.clone(); c.needsUpdate = true; c.repeat.set(rx, ry); return c; }
  function box(w, h, d, material, x, y, z, shadows = true) {
    const m = new T.Mesh(new T.BoxGeometry(w, h, d), material);
    m.position.set(x, y, z); m.castShadow = shadows; m.receiveShadow = true; root.add(m); return m;
  }
  function plane(w, h, material, x, y, z, rx = -Math.PI / 2) {
    const m = new T.Mesh(new T.PlaneGeometry(w, h), material);
    m.rotation.x = rx; m.position.set(x, y, z); m.receiveShadow = true; root.add(m); return m;
  }
  function quad(a, b, c, d, material, uvScale = 1) {
    const g = new T.BufferGeometry();
    const v = [a, b, c, a, c, d].flat();
    const lu = Math.hypot(b[0] - a[0], b[1] - a[1], b[2] - a[2]) / uvScale;
    const lv = Math.hypot(d[0] - a[0], d[1] - a[1], d[2] - a[2]) / uvScale;
    g.setAttribute('position', new T.Float32BufferAttribute(v, 3));
    g.setAttribute('uv', new T.Float32BufferAttribute([0, lv, lu, lv, lu, 0, 0, lv, lu, 0, 0, 0], 2));
    g.computeVertexNormals();
    material.side = T.DoubleSide;
    const m = new T.Mesh(g, material); m.receiveShadow = true; root.add(m); return m;
  }
  function addTag(pos, html, cls, id) {
    const el = document.createElement('div');
    el.className = 'tag ' + (cls || ''); el.innerHTML = html;
    if (id) el.addEventListener('click', (e) => { e.stopPropagation(); select(id); });
    document.getElementById('labels').appendChild(el);
    anchors.push({ pos, el, kind: cls || 'pipe', id });
    return el;
  }

  // Instanced batches: one draw call per kind of object.
  class Batch {
    constructor(geo, material, cast = true) { this.geo = geo; this.material = material; this.items = []; this.cast = cast; }
    add(x, y, z, ry = 0, sx = 1, sy = 1, sz = 1, color) { this.items.push([x, y, z, ry, sx, sy, sz, color]); }
    build() {
      if (!this.items.length) return null;
      const m = new T.InstancedMesh(this.geo, this.material, this.items.length);
      const o = new T.Object3D(), c = new T.Color();
      this.items.forEach((it, i) => {
        o.position.set(it[0], it[1], it[2]); o.rotation.set(0, it[3], 0); o.scale.set(it[4], it[5], it[6]); o.updateMatrix();
        m.setMatrixAt(i, o.matrix);
        if (it[7] !== undefined) m.setColorAt(i, c.set(it[7]));
      });
      if (this.items.some((it) => it[7] === undefined) && m.instanceColor) this.items.forEach((it, i) => { if (it[7] === undefined) m.setColorAt(i, c.set(0xffffff)); });
      m.castShadow = this.cast; m.receiveShadow = true; root.add(m); return m;
    }
  }
  const lift = (g, y) => { g.translate(0, y, 0); return g; };
  let B = null;
  function newBatches() {
    const busMats = [mat({ map: busSideTex, roughness: .5 }), mat({ map: busSideTex, roughness: .5 }), mat({ color: 0xE9ECEE, roughness: .6 }),
      mat({ color: 0x222222 }), mat({ map: busEndTex, roughness: .4 }), mat({ map: busEndTex, roughness: .4 })];
    const glassM = mat({ color: 0x1F2B36, roughness: .15, metalness: .4 });
    B = {
      bus: new Batch(lift(new T.BoxGeometry(2.55, 2.95, 11.5), 1.85), busMats),
      car: new Batch(lift(new T.BoxGeometry(1.8, .75, 4.3), .62), mat({ color: 0xffffff, roughness: .32, metalness: .35 })),
      cab: new Batch(lift(new T.BoxGeometry(1.55, .6, 2.2), 1.28), glassM),
      auto: new Batch(lift(new T.BoxGeometry(1.3, .95, 2.6), .78), mat({ color: 0xE8BE1E, roughness: .5 })),
      autoTop: new Batch(lift(new T.BoxGeometry(1.36, .12, 2.3), 1.62), mat({ color: 0x26452D, roughness: .7 })),
      bike: new Batch(lift(new T.BoxGeometry(.38, .85, 1.8), .55), mat({ color: 0xffffff, roughness: .45, metalness: .3 })),
      person: new Batch(lift(new T.CapsuleGeometry(.22, .85, 4, 8), .66), mat({ color: 0xffffff, roughness: .9 })),
      head: new Batch(lift(new T.SphereGeometry(.17, 10, 8), 1.62), mat({ color: 0x8A5A3C, roughness: .8 }), false),
      trunk: new Batch(lift(new T.CylinderGeometry(.18, .26, 2.6, 7), 1.3), mat({ color: 0x6B4F35 })),
      crown: new Batch(new T.IcosahedronGeometry(1, 1), mat({ color: 0xffffff, roughness: .9, flatShading: true })),
      house: new Batch(lift(new T.BoxGeometry(1, 1, 1), .5), mat({ color: 0xffffff, roughness: .9 })),
      column: new Batch(lift(new T.CylinderGeometry(.22, .22, 1, 10), .5), mat({ color: 0xD9DCDF, roughness: .6 })),
      bench: new Batch(lift(new T.BoxGeometry(2.2, .45, .5), .23), mat({ color: 0x8A5A33, roughness: .8 })),
      shop: new Batch(lift(new T.BoxGeometry(1, 1, 1), .5), mat({ color: 0xffffff, roughness: .85 })),
      awning: new Batch(new T.BoxGeometry(1, .12, 1), mat({ color: 0xffffff, roughness: .7 })),
      cart: new Batch(lift(new T.BoxGeometry(1.4, 1, 2.2), .5), mat({ color: 0xffffff, roughness: .6 })),
      umbrella: new Batch(lift(new T.ConeGeometry(1.5, .7, 10), 2.6), mat({ color: 0xffffff, roughness: .7 })),
      post: new Batch(lift(new T.CylinderGeometry(.07, .07, 1, 6), .5), mat({ color: 0x6B7480, roughness: .5, metalness: .5 })),
      lamp: new Batch(new T.BoxGeometry(.9, .18, .35), new T.MeshBasicMaterial({ color: 0xFFF4C8 }), false),
      drum: new Batch(lift(new T.CylinderGeometry(.3, .3, .9, 12), .45), mat({ color: 0xffffff, roughness: .5, metalness: .3 })),
      stall: new Batch(new T.BoxGeometry(1, .06, 1), new T.MeshBasicMaterial({ color: 0xF2F2EE }), false),
    };
  }

  // ------------------------------------------------------------------ geometry helpers
  const CUT = { x0: 0, x1: 0, z0: 0, z1: 0 };
  function clipZ(r) { const z1 = Math.min(0, r.z1); return z1 - r.z0 < .2 ? null : { ...r, z1 }; }
  // r minus the cut rectangle: up to four pieces
  function minusCut(r) {
    const c = CUT;
    if (r.x1 <= c.x0 || r.x0 >= c.x1 || r.z1 <= c.z0 || r.z0 >= c.z1) return [r];
    const out = [];
    if (r.z0 < c.z0) out.push({ ...r, z1: c.z0 });
    if (r.z1 > c.z1) out.push({ ...r, z0: c.z1 });
    const z0 = Math.max(r.z0, c.z0), z1 = Math.min(r.z1, c.z1);
    if (r.x0 < c.x0) out.push({ ...r, x1: c.x0, z0, z1 });
    if (r.x1 > c.x1) out.push({ ...r, x0: c.x1, z0, z1 });
    return out.filter((p) => p.x1 - p.x0 > .1 && p.z1 - p.z0 > .1);
  }
  function flat(r, material, y) {
    const m = new T.Mesh(new T.PlaneGeometry(r.x1 - r.x0, r.z1 - r.z0), material);
    m.rotation.x = -Math.PI / 2; m.position.set((r.x0 + r.x1) / 2, y, (r.z0 + r.z1) / 2); m.receiveShadow = true; root.add(m); return m;
  }
  function slab(r, material, y, h) {
    return box(r.x1 - r.x0, h, r.z1 - r.z0, material, (r.x0 + r.x1) / 2, y - h / 2, (r.z0 + r.z1) / 2, false);
  }
  function shapeWithCut(outer) {
    const s = new T.Shape();
    s.moveTo(outer.x0, -outer.z1); s.lineTo(outer.x1, -outer.z1); s.lineTo(outer.x1, -outer.z0); s.lineTo(outer.x0, -outer.z0); s.lineTo(outer.x0, -outer.z1);
    const c = CUT;
    if (c.x0 > outer.x0 && c.x1 < outer.x1 && c.z0 > outer.z0 && c.z1 <= outer.z1) {
      const hp = new T.Path();
      hp.moveTo(c.x0, -c.z1 + .001); hp.lineTo(c.x0, -c.z0); hp.lineTo(c.x1, -c.z0); hp.lineTo(c.x1, -c.z1 + .001); hp.lineTo(c.x0, -c.z1 + .001);
      s.holes.push(hp);
    }
    const g = new T.ShapeGeometry(s); g.rotateX(-Math.PI / 2);
    const uv = g.attributes.uv, pos = g.attributes.position;
    for (let i = 0; i < uv.count; i++) uv.setXY(i, pos.getX(i) / 20, pos.getZ(i) / 20);
    return g;
  }
  // point inside rect r: t along the long axis (0..1), s across (-1..1)
  function rectFrame(r) {
    const w = r.x1 - r.x0, d = r.z1 - r.z0, cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2;
    const longX = w > d;
    return {
      w, d, cx, cz, longX, long: Math.max(w, d), short: Math.min(w, d),
      at(t, s) { return longX ? [r.x0 + t * w, cz + s * d / 2] : [cx + s * w / 2, r.z0 + t * d]; },
      ry: longX ? Math.PI / 2 : 0,
    };
  }

  // ------------------------------------------------------------------ build
  function build(d) {
    data = d;
    if (root) { scene.remove(root); root.traverse((o) => { if (o.geometry) o.geometry.dispose(); }); }
    pickables.length = 0; anchors.length = 0; fx.length = 0; runInfo.length = 0;
    document.getElementById('labels').innerHTML = '';
    root = new T.Group(); scene.add(root);
    newBatches();

    // The schematic road is wide; across-road distances are drawn at crossScale so the
    // whole cut fits a phone screen. Depths and sizes are exaggerated; the card shows true values.
    // Inside the road (15 m either side) distances are drawn at crossScale; beyond the
    // road the surroundings are drawn closer still, so what is beside the cut is in view.
    const cs = d.crossScale || .55, R = (d.width || 30) / 2, cs2 = .3;
    const squeeze = (x) => Math.sign(x) * (Math.abs(x) <= R ? Math.abs(x) * cs : R * cs + (Math.abs(x) - R) * cs2);
    const sx = (o, ...keys) => keys.forEach((k) => { if (o[k] !== undefined && o[k] !== null) o[k] = squeeze(o[k]); });
    d.assets.forEach((a) => sx(a, 'x', 'x0', 'x1'));
    (d.works || []).forEach((w) => sx(w, 'x'));
    (d.points || []).forEach((p) => sx(p, 'x'));
    const world = d.world || { zones: [], roads: [] };
    world.zones.forEach((z) => sx(z, 'x0', 'x1'));
    world.roads.forEach((z) => sx(z, 'x0', 'x1'));
    if (world.compound) sx(world.compound, 'x0', 'x1');
    if (world.highway) sx(world.highway, 'x0', 'x1');
    if (world.gate) sx(world.gate, 'x');

    const W = (d.width || 30) * cs, half = W / 2, L = d.length || 24;
    const ds = d.depthScale || 2.5, ss = d.sizeScale || 2.5;
    const runsAll = d.assets.filter((a) => !a.crossing);
    const maxDepth = Math.max(2.2, ...runsAll.map((a) => a.depth + (a.sizeMm || 300) / 1000 * ss));
    const FLOOR = -(maxDepth * ds + 1.4);
    const BASE = FLOOR - 16;
    const topHalf = half + .3, floorHalf = half - 2.5;
    Object.assign(CUT, { x0: -topHalf, x1: topHalf, z0: -L, z1: 0 });
    document.getElementById('t1').textContent = `Underground · ${d.road}`;
    document.getElementById('t2').textContent = `Facing ${d.facing || 'ahead'} · sample records · drawn larger than life · not for excavation`;

    // --- ground: town outside the compound, apron inside, both open at the cut
    const VIEW = { x0: -190, x1: 190, z0: -520, z1: 0 };
    const town = new T.Mesh(shapeWithCut(VIEW), mat({ map: repeatClone(townTex, 1, 1), roughness: 1 }));
    town.position.y = -.06; town.receiveShadow = true; root.add(town);
    const comp = world.compound && clipZ(world.compound);
    if (comp) {
      const ap = new T.Mesh(shapeWithCut(comp), mat({ map: repeatClone(concreteTex, 1, 1), roughness: .95 }));
      ap.position.y = .01; ap.receiveShadow = true; root.add(ap);
      compoundWall(comp, world.gate);
    }
    if (world.highway) highway(world.highway);
    townBuildings(comp, world.highway);

    // --- roads
    world.roads.forEach((rd, i) => road(rd, i, half, L));

    // --- areas of the bus stand
    for (const z of world.zones) {
      const r = clipZ(z);
      if (!r || r.z1 < -380) continue;
      zone(z.kind, z.name, r);
    }
    const selfRoad = world.roads.find((r) => r.self);
    streetLights(half, L, selfRoad);
    if (selfRoad) {
      const r0 = clipZ(selfRoad);
      if (r0) for (const s of [-1, 1]) {
        const fp = s < 0 ? { x0: r0.x0 - 2.6, x1: r0.x0, z0: r0.z0, z1: r0.z1 } : { x0: r0.x1, x1: r0.x1 + 2.6, z0: r0.z0, z1: r0.z1 };
        for (const p of minusCut(fp)) slab(p, mat({ map: repeatClone(concreteTex, 1, (p.z1 - p.z0) / 6), color: 0xD9D6CF }), .2, .2);
        const kb = s < 0 ? { x0: r0.x0 - .3, x1: r0.x0, z0: r0.z0, z1: r0.z1 } : { x0: r0.x1, x1: r0.x1 + .3, z0: r0.z0, z1: r0.z1 };
        for (const p of minusCut(kb)) slab(p, mat({ color: 0xF0EEE8 }), .26, .26);
      }
    }

    // --- the cut
    cut(half, L, FLOOR, BASE, topHalf, floorHalf);

    // --- utilities
    const crossings = d.assets.filter((a) => a.crossing);
    for (const a of crossings) crossingPipe(a, ds, ss, floorHalf, L);
    for (const a of runsAll) utility(a, ds, ss, L);
    for (const p of d.points || []) chamber(p, ds);
    for (const w of d.works || []) workVolume(w, ds, ss, L, runsAll);

    // --- glass digital-twin volume
    const gx = topHalf + 2.5;
    const gb = new T.BoxGeometry(gx * 2, -FLOOR + 3.2, L);
    const edges = new T.LineSegments(new T.EdgesGeometry(gb), new T.LineBasicMaterial({ color: 0xBFE6FF, transparent: true, opacity: .85 }));
    edges.position.set(0, (FLOOR - 2) / 2 + .9 - .6, -L / 2); root.add(edges);
    addTag(new T.Vector3(0, .9, 0), 'SAMANVAY GEO-TWIN', 'twin');

    for (const b of Object.values(B)) b.build();
    effects(half, L, FLOOR, topHalf, floorHalf, runInfo, ds, ss);
    traffic(world, half, L);

    home.target.set(0, FLOOR * .42, -L * .42);
    home.dist = Math.max(36, (W + 8) * 2.2);
    builtAt = performance.now();
    resetView(true);
  }

  // ------------------------------------------------------------------ roads, wall, highway, town
  function road(rd, i, half, L) {
    const r0 = clipZ(rd); if (!r0) return;
    const asphalt = mat({ map: repeatClone(asphaltTex, (r0.x1 - r0.x0) / 8, (r0.z1 - r0.z0) / 8), roughness: .92 });
    const y = .02 + (rd.alongZ ? 0 : .006) + i * .0005;
    for (const p of minusCut(r0)) {
      slab(p, asphalt, y, .3);
      if (rd.self && p.z1 <= CUT.z0 + .01) slab({ x0: p.x0 - 2, x1: p.x1 + 2, z0: p.z0, z1: p.z1 }, mat({ map: repeatClone(gravelTex, 6, 2), roughness: 1 }), y - .3, 1.5);
    }
    // markings along the road axis, outside the cut
    const white = new T.MeshBasicMaterial({ color: 0xF2F2EE }), yellow = new T.MeshBasicMaterial({ color: 0xF0BE2C });
    const mark = (x0, x1, z0, z1, m) => { for (const p of minusCut({ x0, x1, z0, z1 })) flat(p, m, y + .012); };
    if (rd.alongZ) {
      const cx = (r0.x0 + r0.x1) / 2, hw = (r0.x1 - r0.x0) / 2;
      mark(cx - .18, cx - .04, r0.z0 + 2, r0.z1 - 2, yellow); mark(cx + .04, cx + .18, r0.z0 + 2, r0.z1 - 2, yellow);
      for (const s of [-1, 1]) mark(cx + s * (hw - .7) - .09, cx + s * (hw - .7) + .09, r0.z0 + 1, r0.z1 - 1, white);
      for (let z = r0.z1 - 3; z > r0.z0 + 3; z -= 9) for (const s of [-1, 1]) mark(cx + s * hw / 2 - .08, cx + s * hw / 2 + .08, z - 4, z, white);
      if (rd.self) for (let k = 0; k < 9; k++) { const x = cx - hw + 2 + k * (hw * 2 - 4) / 8; mark(x - .35, x + .35, -L - 7, -L - 3, white); }
    } else {
      const cz = (r0.z0 + r0.z1) / 2, hd = (r0.z1 - r0.z0) / 2;
      mark(r0.x0 + 2, r0.x1 - 2, cz - .18, cz - .04, yellow); mark(r0.x0 + 2, r0.x1 - 2, cz + .04, cz + .18, yellow);
      for (let x = r0.x0 + 3; x < r0.x1 - 3; x += 7) for (const s of [-1, 1]) mark(x, x + 3, cz + s * hd / 2 - .08, cz + s * hd / 2 + .08, white);
    }
    if (!rd.self && r0.z1 > -260) {
      const c = rd.alongZ ? new T.Vector3((r0.x0 + r0.x1) / 2, .6, Math.max(r0.z0, -120) * .5 + r0.z1 * .5) : new T.Vector3(Math.max(-60, Math.min(60, (r0.x0 + r0.x1) / 2)), .6, (r0.z0 + r0.z1) / 2);
      addTag(c, rd.name.toUpperCase(), 'road');
    }
  }
  function compoundWall(c, gate) {
    const wallM = mat({ map: repeatClone(concreteTex, 6, 1), color: 0xE8E2D6, roughness: .9 });
    const capM = mat({ color: 0xB4412D, roughness: .7 });
    const seg = (x0, z0, x1, z1) => {
      const len = Math.hypot(x1 - x0, z1 - z0); if (len < .3) return;
      const along = Math.abs(x1 - x0) > Math.abs(z1 - z0);
      box(along ? len : .35, 2.2, along ? .35 : len, wallM, (x0 + x1) / 2, 1.1, (z0 + z1) / 2);
      box(along ? len : .5, .18, along ? .5 : len, capM, (x0 + x1) / 2, 2.25, (z0 + z1) / 2, false);
      for (let t = 0; t <= len; t += 9) B.post.add(x0 + (x1 - x0) * t / len, 0, z0 + (z1 - z0) * t / len, 0, 6, 2.5, 6, 0xC9C2B4);
    };
    const gx = gate ? gate.x : 1e9, gz = gate ? gate.z : 1e9;
    const edges = [[c.x0, c.z0, c.x1, c.z0], [c.x1, c.z0, c.x1, c.z1], [c.x1, c.z1, c.x0, c.z1], [c.x0, c.z1, c.x0, c.z0]];
    for (const [x0, z0, x1, z1] of edges) {
      if (Math.abs(z1 - z0) < .01 && z0 >= -.01) continue;           // the cut face itself
      const onGate = gate && ((Math.abs(z0 - z1) < .01 && Math.abs(z0 - gz) < 2) || (Math.abs(x0 - x1) < .01 && Math.abs(x0 - gx) < 2));
      if (!onGate) { seg(x0, z0, x1, z1); continue; }
      if (Math.abs(z0 - z1) < .01) { const a = Math.min(x0, x1), b = Math.max(x0, x1); seg(a, z0, gx - 9, z0); seg(gx + 9, z0, b, z0); }
      else { const a = Math.min(z0, z1), b = Math.max(z0, z1); seg(x0, a, x0, gz - 9); seg(x0, gz + 9, x0, b); }
    }
    if (gate && gate.z <= 0 && gate.z > -400) gateArch(gate, edges);
  }
  function gateArch(gate, edges) {
    const pM = mat({ color: 0xE9E2D2, roughness: .8 });
    const acrossX = edges.some(([x0, z0, x1, z1]) => Math.abs(z0 - z1) < .01 && Math.abs(z0 - gate.z) < 2);
    const off = (s) => acrossX ? [gate.x + s * 8.5, gate.z] : [gate.x, gate.z + s * 8.5];
    for (const s of [-1, 1]) { const [x, z] = off(s); box(1.6, 8, 1.6, pM, x, 4, z); }
    const beam = box(acrossX ? 18.6 : 1.4, 1.6, acrossX ? 1.4 : 18.6, mat({ color: 0x1C6B45, roughness: .6 }), gate.x, 8.2, gate.z);
    beam.castShadow = true;
    const t = signTex('MANAPARAI BUS STAND', '#1C6B45', '#FFFFFF', 1024, 96);
    for (const s of [-1, 1]) {
      const p = new T.Mesh(new T.PlaneGeometry(17, 1.4), new T.MeshBasicMaterial({ map: t }));
      if (acrossX) { p.position.set(gate.x, 8.2, gate.z + s * .72); if (s < 0) p.rotation.y = Math.PI; }
      else { p.position.set(gate.x + s * .72, 8.2, gate.z); p.rotation.y = s * Math.PI / 2; }
      root.add(p);
    }
    addTag(new T.Vector3(gate.x, 10.5, gate.z), 'MAIN ENTRANCE', 'place');
  }
  function highway(hw) {
    const r = clipZ(hw); if (!r) return;
    const along = (r.x1 - r.x0) > (r.z1 - r.z0);
    const a = mat({ map: repeatClone(asphaltTex, (r.x1 - r.x0) / 8, (r.z1 - r.z0) / 8), roughness: .92 });
    slab(r, a, .03, .3);
    const yel = new T.MeshBasicMaterial({ color: 0xF0BE2C }), wht = new T.MeshBasicMaterial({ color: 0xF2F2EE });
    if (along) {
      for (const z of [r.z0 + .6, r.z1 - .6]) flat({ x0: r.x0, x1: r.x1, z0: z - .1, z1: z + .1 }, yel, .045);
      const cz = (r.z0 + r.z1) / 2; for (let x = r.x0; x < r.x1; x += 12) flat({ x0: x, x1: x + 6, z0: cz - .1, z1: cz + .1 }, wht, .045);
    } else {
      for (const x of [r.x0 + .6, r.x1 - .6]) flat({ x0: x - .1, x1: x + .1, z0: r.z0, z1: r.z1 }, yel, .045);
      const cx = (r.x0 + r.x1) / 2; for (let z = r.z1; z > r.z0; z -= 12) flat({ x0: cx - .1, x1: cx + .1, z0: z - 6, z1: z }, wht, .045);
    }
    addTag(new T.Vector3((Math.max(r.x0, -50) + Math.min(r.x1, 50)) / 2, 1.2, (Math.max(r.z0, -200) + r.z1) / 2), 'SH 71A · STATE HIGHWAY', 'road');
  }
  function townBuildings(comp, hw) {
    const r = rng(Math.round(((comp ? comp.x0 * 7 + comp.z0 * 3 : 1)) * 1000) >>> 0);
    const inside = (x, z, m) => comp && x > comp.x0 - m && x < comp.x1 + m && z > comp.z0 - m && z < comp.z1 + m;
    const onHw = (x, z) => hw && x > hw.x0 - 4 && x < hw.x1 + 4 && z > hw.z0 - 4 && z < hw.z1 + 4;
    const cols = [0xE8DCC6, 0xD9C7A8, 0xC9D3C8, 0xE2CFC0, 0xF0E6D6, 0xBFC8CF, 0xD7B79A, 0xE9E1F0];
    for (let z = -6; z > -420; z -= 14) {
      for (let x = -180; x < 180; x += 13) {
        const px = x + r() * 5, pz = z - r() * 5;
        if (inside(px, pz, 10) || onHw(px, pz) || (Math.abs(px) < 22 && pz > -60) || r() < .38) continue;
        const w = 6 + r() * 6, dd = 6 + r() * 6, h = 3 + r() * (r() < .2 ? 10 : 5);
        B.house.add(px, 0, pz, 0, w, h, dd, cols[(r() * cols.length) | 0]);
        if (r() < .35) treeAt(px + w / 2 + 2, pz + 1, r);
      }
    }
    // trees just outside the wall
    if (comp) for (let t = 0; t < 70; t++) {
      const side = (r() * 4) | 0, u = r();
      const x = side === 0 ? comp.x0 - 4 - r() * 3 : side === 1 ? comp.x1 + 4 + r() * 3 : comp.x0 + u * (comp.x1 - comp.x0);
      const z = side < 2 ? comp.z0 + u * (comp.z1 - comp.z0) : side === 2 ? comp.z0 - 4 - r() * 3 : comp.z1 + 4;
      if (z <= -1 && !(Math.abs(x) < CUT.x1 + 3 && z > CUT.z0)) treeAt(x, z, r);
    }
  }
  function treeAt(x, z, r) {
    const s = .8 + r() * .7;
    B.trunk.add(x, 0, z, 0, s, s, s);
    const leaf = [0x4F6B3A, 0x5E7E44, 0x6E8C52, 0x587A3E];
    for (let i = 0; i < 3; i++) B.crown.add(x + (r() - .5) * 1.6 * s, (3 + r() * 1.3) * s, z + (r() - .5) * 1.6 * s, r() * 3, 1.6 * s, 1.4 * s, 1.6 * s, leaf[(r() * 4) | 0]);
  }
  function streetLights(half, L, self) {
    if (!self) return;
    const r0 = clipZ(self); if (!r0) return;
    for (const s of [-1, 1]) for (let z = -L - 4; z > Math.max(r0.z0, -260); z -= 26) {
      const x = s * (half + 2.2);
      B.post.add(x, 0, z, 0, 1.2, 7.5, 1.2);
      B.lamp.add(x - s * .9, 7.4, z, 0);
    }
  }

  // ------------------------------------------------------------------ areas of the bus stand
  const BUS_COLS = [0xB4412D, 0x2C7A6B, 0xCF8A1E, 0x3D5F99, 0x8E2F2F, 0x2F6B8E];
  const CLOTHES = [0xC0392B, 0x2E86C1, 0xF4D03F, 0x27AE60, 0x8E44AD, 0xE67E22, 0xECF0F1, 0x34495E, 0xD35400, 0x16A085];
  function people(f, n, t0, t1, s0, s1, r) {
    for (let i = 0; i < n; i++) {
      const [x, z] = f.at(t0 + r() * (t1 - t0), s0 + r() * (s1 - s0));
      B.person.add(x, 0, z, r() * 6, 1, .9 + r() * .2, 1, CLOTHES[(r() * CLOTHES.length) | 0]);
      B.head.add(x, 0, z);
    }
  }
  function zone(kind, name, r) {
    const f = rectFrame(r);
    const rr = rng(Math.round(Math.abs(r.x0 * 13 + r.z0 * 7)) + 11);
    const conc = mat({ map: repeatClone(concreteTex, f.w / 12, f.d / 12), roughness: .95 });
    const asph = mat({ map: repeatClone(asphaltTex, f.w / 10, f.d / 10), color: 0xB5B8BC, roughness: .92 });
    const n = (frac) => Math.max(1, Math.floor(f.long * frac));
    const nm = name || '';
    if (kind === 'platform') {
      slab(r, conc, .14, .14);
      // passenger island with a canopy
      const [ix, iz] = f.at(.5, .25);
      const isl = f.longX ? { x0: r.x0 + 2, x1: r.x1 - 2, z0: iz - f.short * .1, z1: iz + f.short * .1 } : { x0: ix - f.short * .1, x1: ix + f.short * .1, z0: r.z0 + 2, z1: r.z1 - 2 };
      slab(isl, mat({ map: repeatClone(tileTex, 4, 4), color: 0xF3E9D6 }), .42, .28);
      const edgeX = f.longX ? null : isl.x0, edgeZ = f.longX ? isl.z0 : null;
      flat(f.longX ? { x0: isl.x0, x1: isl.x1, z0: edgeZ, z1: edgeZ + .35 } : { x0: edgeX, x1: edgeX + .35, z0: isl.z0, z1: isl.z1 }, new T.MeshBasicMaterial({ color: 0xF0BE2C }), .43);
      const can = f.longX ? { x0: isl.x0, x1: isl.x1, z0: iz - f.short * .16, z1: iz + f.short * .16 } : { x0: ix - f.short * .16, x1: ix + f.short * .16, z0: isl.z0, z1: isl.z1 };
      const roof = slab(can, mat({ color: 0xE6EAEE, roughness: .45, metalness: .2 }), 5.0, .3); roof.castShadow = true;
      for (let t = 0; t <= 1; t += 1 / n(.09)) { const [x, z] = f.at(.02 + t * .96, .25); B.column.add(x, .42, z, 0, 1, 4.4, 1); }
      people(f, n(.6), .05, .95, .12, .38, rr);
      // buses angled into the bays on the open side
      const step = 9 / f.long;
      for (let t = .04, i = 0; t < .96; t += step, i++) {
        if (rr() < .28) continue;
        const [x, z] = f.at(t, -.45);
        B.bus.add(x, .14, z, f.ry + .55, 1, 1, 1, BUS_COLS[(rr() * BUS_COLS.length) | 0]);
      }
    } else if (kind === 'bays') {
      slab(r, asph, .1, .1);
      const step = 4.6 / f.long;
      for (const s of [-.55, .55]) for (let t = .03; t < .97; t += step) {
        const [x, z] = f.at(t, s); const [x2, z2] = f.at(t, s * .2);
        B.stall.add((x + x2) / 2, .12, (z + z2) / 2, f.ry, f.longX ? .14 : Math.abs(x - x2) + .1, 1, f.longX ? Math.abs(z - z2) + .1 : .14);
        if (rr() < .62) { const [bx, bz] = f.at(t + step / 2, s * 1.18 > 0 ? .62 : -.62); B.bus.add(bx, .1, bz, f.ry + Math.PI / 2, 1, 1, 1, BUS_COLS[(rr() * BUS_COLS.length) | 0]); }
      }
      people(f, n(.06), .05, .95, -.1, .1, rr);
    } else if (kind === 'parking' && /two/i.test(nm)) {
      slab(r, asph, .1, .1);
      // covered two-wheeler shed
      const shed = { x0: r.x0 + 1.5, x1: r.x1 - 1.5, z0: r.z0 + 1.5, z1: r.z1 - 1.5 };
      for (let t = 0; t <= 1; t += 1 / n(.06)) for (const s of [-.85, .85]) { const [x, z] = f.at(.02 + t * .96, s); B.post.add(x, .1, z, 0, 1.6, 3.6, 1.6); }
      const roof = slab(shed, mat({ color: 0x3D7A8C, roughness: .5, metalness: .3, transparent: true, opacity: .55 }), 3.9, .12); roof.castShadow = false;
      const bikeCols = [0x1F2933, 0x8E2F2F, 0x2E4D7A, 0x55606B, 0xB4412D, 0xE6E6E6];
      for (const s of [-.5, .5]) for (let t = .03; t < .97; t += .9 / f.long) if (rr() < .78) { const [x, z] = f.at(t, s); B.bike.add(x, .1, z, f.ry + Math.PI / 2, 1, 1, 1, bikeCols[(rr() * 6) | 0]); }
    } else if (kind === 'parking') {
      slab(r, asph, .1, .1);
      for (const s of [-.55, 0, .55]) for (let t = .04; t < .96; t += 2.2 / f.long) if (rr() < .7) {
        const [x, z] = f.at(t, s);
        if (rr() < .82) { B.auto.add(x, .1, z, f.ry + Math.PI / 2); B.autoTop.add(x, .1, z, f.ry + Math.PI / 2); }
        else { B.car.add(x, .1, z, f.ry + Math.PI / 2, 1, 1, 1, 0xE8C21E); B.cab.add(x, .1, z, f.ry + Math.PI / 2); }
      }
      const [kx, kz] = f.at(.05, 0); box(3, 2.6, 3, mat({ color: 0xF1E4CE }), kx, 1.4, kz);
      people(f, n(.08), .02, .3, -.3, .3, rr);
    } else if (kind === 'concourse') {
      slab(r, mat({ map: repeatClone(tileTex, f.w / 6, f.d / 6) }), .12, .12);
      const cols = n(.08);
      for (let i = 0; i <= cols; i++) for (const s of [-.85, 0, .85]) { const [x, z] = f.at(.02 + .96 * i / cols, s); B.column.add(x, .12, z, 0, 1.3, 6.2, 1.3); }
      for (let t = .06; t < .94; t += 3.2 / f.long) for (const s of [-.55, -.3, .3, .55]) { const [x, z] = f.at(t, s); B.bench.add(x, .12, z, f.ry + Math.PI / 2); }
      people(f, n(.9), .03, .97, -.9, .9, rr);
      // roof with skylights, lifted so the hall stays visible
      const roof = slab({ x0: r.x0 + 1, x1: r.x1 - 1, z0: r.z0 + 1, z1: r.z1 - 1 }, mat({ color: 0x5E7F86, roughness: .5, metalness: .2, transparent: true, opacity: .62 }), 6.7, .35);
      roof.castShadow = true;
      departureBoard(f, r);
    } else if (kind === 'admin') {
      slab(r, conc, .1, .1);
      const rooms = [['TICKETS', 0x2C7A6B], ['ENQUIRY', 0x3D5F99], ['TOILETS', 0x6B7480]];
      rooms.forEach(([label, col], i) => {
        const t0 = .04 + i * .32, t1 = t0 + .28;
        const [x0, z0] = f.at(t0, -.7), [x1, z1] = f.at(t1, .5);
        const bx = { x0: Math.min(x0, x1), x1: Math.max(x0, x1), z0: Math.min(z0, z1), z1: Math.max(z0, z1) };
        const b = slab(bx, mat({ color: 0xEFE4CF, roughness: .9 }), 4.6, 4.5); b.castShadow = true;
        slab({ x0: bx.x0 - .3, x1: bx.x1 + .3, z0: bx.z0 - .3, z1: bx.z1 + .3 }, mat({ color: col, roughness: .7 }), 4.9, .3);
        const sign = new T.Mesh(new T.PlaneGeometry(Math.min(9, (bx.x1 - bx.x0) * .9 + 2), 1.4), new T.MeshBasicMaterial({ map: signTex(label, '#' + col.toString(16).padStart(6, '0'), '#FFFFFF'), side: T.DoubleSide }));
        sign.position.set((bx.x0 + bx.x1) / 2, 6.1, bx.z1 + .01); root.add(sign);
        const [qx, qz] = f.at((t0 + t1) / 2, .75);
        for (let k = 0; k < 6; k++) { const [px, pz] = f.at((t0 + t1) / 2 + (rr() - .5) * .05, .7 + k * .04); B.person.add(px, .1, pz, 0, 1, 1, 1, CLOTHES[(rr() * 10) | 0]); B.head.add(px, .1, pz); }
        void qx; void qz;
      });
    } else if (kind === 'commons') {
      slab(r, mat({ map: repeatClone(tileTex, f.w / 6, f.d / 6) }), .1, .1);
      const aw = [0xC8553D, 0x2C7A6B, 0xD9A43A, 0x3D5F99, 0x8E4B7A];
      const unit = 8;
      for (const s of [-1, 1]) for (let t = .02, i = 0; t < .98 - unit / f.long; t += unit / f.long, i++) {
        const [x, z] = f.at(t + unit / f.long / 2, s * .72);
        const sx = f.longX ? unit - .6 : f.short * .26, sz = f.longX ? f.short * .26 : unit - .6;
        B.shop.add(x, .1, z, 0, sx, 3.6 + (i % 3) * .5, sz, [0xF1E6D2, 0xE8D9BF, 0xF5EEE0][i % 3]);
        const [ax, az] = f.at(t + unit / f.long / 2, s * .45);
        B.awning.add(ax, 3.0, az, 0, f.longX ? unit - .8 : 2.2, 1, f.longX ? 2.2 : unit - .8, aw[(i + (s > 0 ? 2 : 0)) % aw.length]);
      }
      const cart = [0xD35400, 0x16A085, 0xC0392B, 0x2980B9];
      for (let t = .08; t < .92; t += 14 / f.long) { const [x, z] = f.at(t, (rr() - .5) * .3); B.cart.add(x, .1, z, f.ry, 1, 1, 1, cart[(rr() * 4) | 0]); B.umbrella.add(x, .1, z, 0, 1, 1, 1, [0xF4D03F, 0xE74C3C, 0x3498DB, 0xFFFFFF][(rr() * 4) | 0]); }
      people(f, n(.7), .03, .97, -.3, .3, rr);
    } else if (kind === 'depot') {
      slab(r, asph, .1, .1);
      // saw-tooth workshop shed
      const bays = Math.max(2, Math.round(f.long / 14));
      for (let i = 0; i < bays; i++) {
        const t0 = .05 + .9 * i / bays, t1 = .05 + .9 * (i + 1) / bays;
        const [x0, z0] = f.at(t0, -.8), [x1, z1] = f.at(t1, .8);
        const tri = new T.Shape(); tri.moveTo(0, 0); tri.lineTo(1, 0); tri.lineTo(0, 1); tri.lineTo(0, 0);
        const g = new T.ExtrudeGeometry(tri, { depth: 1, bevelEnabled: false });
        const m = new T.Mesh(g, mat({ color: i % 2 ? 0x9AA6B0 : 0xA9B4BD, roughness: .6, metalness: .3 }));
        const lx = Math.abs(x1 - x0), lz = Math.abs(z1 - z0);
        if (f.longX) { m.scale.set(lx, 3, lz); m.position.set(Math.min(x0, x1), 5, Math.max(z0, z1)); m.rotation.y = 0; }
        else { m.rotation.y = Math.PI / 2; m.scale.set(lz, 3, lx); m.position.set(Math.min(x0, x1), 5, Math.min(z0, z1)); }
        m.castShadow = true; root.add(m);
        const [cx, cz] = f.at((t0 + t1) / 2, .85); B.column.add(cx, .1, cz, 0, 1.4, 5, 1.4);
        const [dx, dz] = f.at((t0 + t1) / 2, -.85); B.column.add(dx, .1, dz, 0, 1.4, 5, 1.4);
        const [bx, bz] = f.at((t0 + t1) / 2, rr() < .5 ? -.2 : .3); B.bus.add(bx, .1, bz, f.ry + Math.PI / 2, 1, 1, 1, BUS_COLS[i % BUS_COLS.length]);
      }
      for (let k = 0; k < 12; k++) { const [x, z] = f.at(.92 + rr() * .06, (rr() - .5) * 1.4); B.drum.add(x, .1, z, 0, 1, 1, 1, [0x2E86C1, 0xC0392B, 0x27AE60][(rr() * 3) | 0]); }
      people(f, 6, .1, .9, -.4, .4, rr);
    } else if (kind === 'utility') {
      slab(r, mat({ map: repeatClone(gravelTex, f.w / 4, f.d / 4), roughness: 1 }), .08, .08);
      // fence
      const perim = [[r.x0, r.z0, r.x1, r.z0], [r.x1, r.z0, r.x1, r.z1], [r.x1, r.z1, r.x0, r.z1], [r.x0, r.z1, r.x0, r.z0]];
      const pts = [];
      for (const [x0, z0, x1, z1] of perim) {
        const len = Math.hypot(x1 - x0, z1 - z0);
        for (let t = 0; t <= len; t += 3) B.post.add(x0 + (x1 - x0) * t / len, 0, z0 + (z1 - z0) * t / len, 0, 1, 2.4, 1);
        for (const y of [.8, 1.6, 2.3]) pts.push(x0, y, z0, x1, y, z1);
      }
      const fg = new T.BufferGeometry(); fg.setAttribute('position', new T.Float32BufferAttribute(pts, 3));
      root.add(new T.LineSegments(fg, new T.LineBasicMaterial({ color: 0x9AA3AC })));
      // overhead water tank on legs
      const [tx, tz] = f.at(.25, 0);
      for (const [dx, dz] of [[-2.5, -2.5], [2.5, -2.5], [2.5, 2.5], [-2.5, 2.5]]) box(.4, 11, .4, mat({ color: 0xC9C2B4 }), tx + dx, 5.5, tz + dz);
      const tank = new T.Mesh(new T.CylinderGeometry(4.2, 4.2, 4.6, 32), mat({ color: 0xDCD6CA, roughness: .8 }));
      tank.position.set(tx, 13.3, tz); tank.castShadow = true; root.add(tank);
      const tankTop = new T.Mesh(new T.ConeGeometry(4.4, 1.2, 32), mat({ color: 0xB9B2A4 })); tankTop.position.set(tx, 16.2, tz); root.add(tankTop);
      addTag(new T.Vector3(tx, 18, tz), 'OVERHEAD WATER TANK', 'place');
      // transformer with radiator fins and insulators
      const [ex, ez] = f.at(.62, 0);
      box(4, .6, 3, mat({ color: 0xB5B0A6 }), ex, .3, ez);
      box(2.6, 2.4, 1.8, mat({ color: 0x5F6B5E, roughness: .5, metalness: .4 }), ex, 1.8, ez);
      for (let k = -2; k <= 2; k++) box(.08, 1.8, 1.6, mat({ color: 0x55604F, metalness: .4 }), ex + k * .32, 1.8, ez + 1.1);
      for (const k of [-.7, 0, .7]) { const ins = new T.Mesh(new T.CylinderGeometry(.09, .14, .9, 8), mat({ color: 0xA94434 })); ins.position.set(ex + k, 3.45, ez); root.add(ins); }
      addTag(new T.Vector3(ex, 5, ez), 'TRANSFORMER', 'place');
      const [px, pz] = f.at(.85, 0); box(4, 3, 4, mat({ color: 0xEFE4CF }), px, 1.5, pz);
    } else {
      const b = slab({ x0: r.x0 + 2, x1: r.x1 - 2, z0: r.z0 + 2, z1: r.z1 - 2 }, mat({ color: 0xEFE4CF }), 4, 4); b.castShadow = true;
    }
    if (name && r.z1 > -220) addTag(new T.Vector3(Math.max(-40, Math.min(40, f.cx)), kind === 'utility' ? 3 : 8, Math.max(r.z0 + 4, Math.min(r.z1 - 4, -30))), name.toUpperCase(), 'place');
  }
  function departureBoard(f, r) {
    const c = document.createElement('canvas'); c.width = 512; c.height = 256;
    const g = c.getContext('2d');
    const t = new T.CanvasTexture(c); t.encoding = T.sRGBEncoding;
    const routes = [['TRICHY', '06:40', '4'], ['DINDIGUL', '06:55', '2'], ['MADURAI', '07:10', '7'], ['KARUR', '07:25', '1'], ['THUVARANKURICHI', '07:30', '5'], ['VIRALIMALAI', '07:45', '3']];
    let k = 0;
    const draw = () => {
      g.fillStyle = '#0B1016'; g.fillRect(0, 0, 512, 256);
      g.fillStyle = '#F0BE2C'; g.font = 'bold 26px Roboto, sans-serif'; g.fillText('DEPARTURES', 20, 36);
      g.font = 'bold 22px Roboto, sans-serif';
      for (let i = 0; i < 5; i++) {
        const [to, time, bay] = routes[(i + k) % routes.length];
        g.fillStyle = i === 0 ? '#7CFC9A' : '#FFD66B';
        g.fillText(to, 20, 76 + i * 36); g.fillText(time, 330, 76 + i * 36); g.fillText('BAY ' + bay, 420, 76 + i * 36);
      }
      t.needsUpdate = true;
    };
    draw();
    const [x, z] = f.at(.5, .95);
    const board = new T.Mesh(new T.PlaneGeometry(8, 4), new T.MeshBasicMaterial({ map: t, side: T.DoubleSide }));
    board.position.set(x, 4.2, Math.min(z, r.z1) + .2); root.add(board);
    box(.3, 2.4, .3, mat({ color: 0x3A4550 }), x, 1.2, Math.min(z, r.z1) + .2);
    let acc = 0;
    fx.push((dt) => { acc += dt; if (acc > 2.2) { acc = 0; k++; draw(); } });
  }

  // ------------------------------------------------------------------ the cut
  function cut(half, L, FLOOR, BASE, topHalf, floorHalf) {
    const soilM = (rx, ry) => mat({ map: repeatClone(soilTex, rx, ry), roughness: 1 });
    quad([-topHalf, -1.85, -L], [topHalf, -1.85, -L], [floorHalf, FLOOR, -L], [-floorHalf, FLOOR, -L], soilM(.1, 1 / Math.max(1, -FLOOR)), 1);
    quad([-floorHalf, FLOOR, 0], [floorHalf, FLOOR, 0], [floorHalf, FLOOR, -L], [-floorHalf, FLOOR, -L], mat({ map: repeatClone(floorTex, .12, .12), roughness: 1 }), 1);
    quad([-topHalf, 0, -L], [-topHalf, 0, 0], [-floorHalf, FLOOR, 0], [-floorHalf, FLOOR, -L], soilM(.08, 1 / Math.max(1, -FLOOR)), 1);
    quad([topHalf, 0, 0], [topHalf, 0, -L], [floorHalf, FLOOR, -L], [floorHalf, FLOOR, 0], soilM(.08, 1 / Math.max(1, -FLOOR)), 1);
    // front cut face across the whole view, open where the pit is
    const faceW = 190;
    const shape = new T.Shape();
    shape.moveTo(-faceW, 0); shape.lineTo(faceW, 0); shape.lineTo(faceW, BASE); shape.lineTo(-faceW, BASE); shape.lineTo(-faceW, 0);
    const hole = new T.Path();
    hole.moveTo(-topHalf, 0); hole.lineTo(-floorHalf, FLOOR); hole.lineTo(floorHalf, FLOOR); hole.lineTo(topHalf, 0); hole.lineTo(-topHalf, 0);
    shape.holes.push(hole);
    const fg = new T.ShapeGeometry(shape);
    const fuv = fg.attributes.uv;
    for (let i = 0; i < fuv.count; i++) fuv.setXY(i, (fg.attributes.position.getX(i) + faceW) / 28, 1 + fg.attributes.position.getY(i) / -BASE);
    const rock = strataTexture(FLOOR, BASE); rock.repeat.set(1, 1);
    const face = new T.Mesh(fg, mat({ map: rock, roughness: 1 }));
    face.receiveShadow = true; root.add(face);
  }

  // --------------------------------------------------------------- utilities
  const runInfo = [];   // { a, x, y, r, z0, z1, kind } for effects and clash checks
  function radiusOf(a, ss) { return Math.max(.14, (a.sizeMm || 150) / 2000 * ss); }
  function pipeMaterial(a, len) {
    const k = KIND[a.kind] || KIND.water;
    const map = labelTexture(`${k.text}  ·  ${a.size || ''}`, hex(k.color), Math.max(1, Math.round(len / 7)));
    return new T.MeshStandardMaterial({ map, color: 0xffffff, roughness: a.kind === 'storm' ? .9 : .32, metalness: .05, envMap, envMapIntensity: .35 });
  }
  function tube(a, x, y, r, len, material, group, z0 = 0) {
    const g = new T.CylinderGeometry(r, r, len, 40, 1, true);
    g.rotateX(Math.PI / 2);
    const m = new T.Mesh(g, material); m.position.set(x, y, z0 - len / 2); m.castShadow = true; m.receiveShadow = true;
    group.add(m);
    const inner = new T.Mesh(g.clone().scale(.9, .9, 1), new T.MeshStandardMaterial({ color: 0x15181B, roughness: 1, side: T.BackSide }));
    inner.position.copy(m.position); group.add(inner);
    const ring = new T.Mesh(new T.RingGeometry(r * .88, r, 40), new T.MeshStandardMaterial({ color: new T.Color((KIND[a.kind] || KIND.water).color).multiplyScalar(.92), roughness: .5 }));
    ring.position.set(x, y, z0 + .001); group.add(ring);
    m.userData.id = a.id; pickables.push(m);
    return m;
  }
  function utility(a, ds, ss, L) {
    const k = KIND[a.kind] || KIND.water;
    const z0 = a.z0 !== undefined ? a.z0 : 0, z1 = a.z1 !== undefined ? a.z1 : -L;
    const len = Math.max(.5, z0 - z1);
    const group = new T.Group(); group.userData.id = a.id; root.add(group);
    const y = -a.depth * ds;
    let top = y, r = radiusOf(a, ss);
    const lanes = [];
    if (a.kind === 'storm') {
      const s = r * 1.45;
      const sh = new T.Shape(); sh.moveTo(-s, -s); sh.lineTo(s, -s); sh.lineTo(s, s); sh.lineTo(-s, s); sh.lineTo(-s, -s);
      const hp = new T.Path(); hp.absarc(0, 0, r, 0, Math.PI * 2, true); sh.holes.push(hp);
      const g = new T.ExtrudeGeometry(sh, { depth: len, bevelEnabled: true, bevelSize: .05, bevelThickness: .05, bevelSegments: 1, curveSegments: 40 });
      const m = new T.Mesh(g, new T.MeshStandardMaterial({ map: repeatClone(concreteTex, .3, .3), color: 0xEDEDE8, roughness: .95 }));
      m.position.set(a.x, y, z0 - len); m.castShadow = m.receiveShadow = true; group.add(m);
      const inner = new T.Mesh(new T.CylinderGeometry(r, r, len, 40, 1, true).rotateX(Math.PI / 2), new T.MeshStandardMaterial({ color: 0x101316, side: T.BackSide, roughness: 1 }));
      inner.position.set(a.x, y, z0 - len / 2); group.add(inner);
      m.userData.id = a.id; pickables.push(m);
      top = y + s; lanes.push([a.x, y + r * .2]);   // water flowing inside the barrel, seen through the open end
    } else if (a.kind === 'electricity' || a.kind === 'telecom') {
      const rows = a.kind === 'electricity' ? 3 : 4, cols = 3;
      r = (a.kind === 'electricity' ? .2 : .18) * ss / 2.5 * 1.25;
      const material = pipeMaterial(a, len);
      for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
        const px = a.x + (j - (cols - 1) / 2) * r * 2.12, py = y + ((rows - 1) / 2 - i) * r * 2.12;
        tube(a, px, py, r, len, material, group, z0);
        if (i === 0) lanes.push([px, py + r + .02]);
      }
      top = y + rows * r * 1.06;
      r = rows * r * 1.06;
    } else if (a.kind === 'fibre') {
      r = Math.max(.2, radiusOf(a, ss) * .8); const material = pipeMaterial(a, len);
      for (const s of [-1, 1]) { tube(a, a.x + s * r * 1.15, y, r, len, material, group, z0); lanes.push([a.x + s * r * 1.15, y + r + .02]); }
      top = y + r; r *= 2.2;
    } else {
      tube(a, a.x, y, r, len, pipeMaterial(a, len), group, z0);
      top = y + r; lanes.push([a.x, y + r + .02]);
    }
    runInfo.push({ a, x: a.x, y, r, top, z0, z1, kind: a.kind, lanes });
    const sub = [a.size, `${a.depth.toFixed(1)} m`].filter(Boolean).join(' · ');
    if (!a.noTag) addTag(new T.Vector3(a.x, top, z0), `<b>${k.tag.toUpperCase()}</b><span>${sub}</span>`, 'pipe', a.id);
  }
  function crossingPipe(a, ds, ss, floorHalf, L) {
    const k = KIND[a.kind] || KIND.water;
    const z = Math.max(-L + .6, Math.min(-.6, a.z ?? -L / 2));
    const x0 = Math.max(-floorHalf - 2.5, Math.min(a.x0 ?? -floorHalf, a.x1 ?? floorHalf)), x1 = Math.min(floorHalf + 2.5, Math.max(a.x0 ?? -floorHalf, a.x1 ?? floorHalf));
    if (x1 - x0 < .3) return;
    const r = a.junction ? Math.max(.14, (a.sizeMm || 100) / 2000 * ss) : Math.max(.1, (a.sizeMm || 63) / 2000 * ss);
    const g = new T.CylinderGeometry(r, r, x1 - x0, 24); g.rotateZ(Math.PI / 2);
    const m = new T.Mesh(g, new T.MeshStandardMaterial({ color: k.color, roughness: .4, envMap, envMapIntensity: .3 }));
    m.position.set((x0 + x1) / 2, -a.depth * ds, z); m.castShadow = true; root.add(m);
    m.userData.id = a.id; pickables.push(m);
    if (a.junction) addTag(new T.Vector3(x1, -a.depth * ds + r, z), `<b>${k.tag.toUpperCase()}</b><span>crossing · ${a.road}</span>`, 'pipe', a.id);
  }
  function chamber(p, ds) {
    const depth = Math.max(1, p.depth * ds + .6);
    const brick = tex(128, 128, (g, w, h) => {
      g.fillStyle = '#9C5B3E'; g.fillRect(0, 0, w, h);
      g.strokeStyle = '#D9CBB6'; g.lineWidth = 3;
      for (let y = 0; y <= h; y += 16) { g.beginPath(); g.moveTo(0, y); g.lineTo(w, y); g.stroke(); for (let x = (y / 16) % 2 ? 0 : 16; x < w; x += 32) { g.beginPath(); g.moveTo(x, y); g.lineTo(x, y + 16); g.stroke(); } }
    }, 2, depth / 1.2);
    const shaft = new T.Mesh(new T.CylinderGeometry(.62, .62, depth, 20, 1, true), mat({ map: brick, side: T.DoubleSide }));
    shaft.position.set(p.x, -depth / 2, p.z); shaft.castShadow = true; root.add(shaft);
    const cover = new T.Mesh(new T.CylinderGeometry(.7, .7, .08, 20), mat({ color: 0x2E3236, metalness: .6, roughness: .5 }));
    cover.position.set(p.x, .06, p.z); root.add(cover);
    shaft.userData.id = p.id; pickables.push(shaft);
  }
  function workVolume(w, ds, ss, L, runs) {
    const z0 = Math.min(0, w.z0 ?? 0), z1 = Math.max(-L, w.z1 ?? -L);
    const len = Math.max(.5, z0 - z1), depth = (w.depth || 1.5) * ds, width = Math.max(1.2, (w.width || .6) * 2.6);
    const g = new T.BoxGeometry(width, depth, len);
    const m = new T.Mesh(g, new T.MeshBasicMaterial({ color: 0x2A72DE, transparent: true, opacity: .13, depthWrite: false }));
    m.position.set(w.x, -depth / 2, z0 - len / 2); root.add(m);
    const e = new T.LineSegments(new T.EdgesGeometry(g), new T.LineDashedMaterial({ color: 0x2A72DE, dashSize: .7, gapSize: .45 }));
    e.computeLineDistances(); e.position.copy(m.position); root.add(e);
    // clashes: records inside or touching the planned trench
    let clashes = 0;
    for (const ri of runInfo) {
      const zo0 = Math.min(z0, ri.z0), zo1 = Math.max(z1, ri.z1);
      if (zo0 - zo1 < .3) continue;
      if (Math.abs(ri.x - w.x) > width / 2 + ri.r + .15) continue;
      if (ri.top < -depth - .1) continue;
      clashes++;
      const shell = new T.Mesh(new T.CylinderGeometry(ri.r * 1.5 + .15, ri.r * 1.5 + .15, zo0 - zo1, 28, 1, true).rotateX(Math.PI / 2),
        new T.MeshBasicMaterial({ color: 0xFF2A1F, transparent: true, opacity: .3, depthWrite: false, side: T.DoubleSide }));
      shell.position.set(ri.x, ri.y, (zo0 + zo1) / 2); root.add(shell);
      const ph = clashes * 1.3;
      fx.push((dt, t) => { const k = .5 + .5 * Math.sin(t * 5 + ph); shell.material.opacity = .12 + .3 * k; shell.scale.set(1 + .1 * k, 1 + .1 * k, 1); });
    }
    const note = clashes ? ` · ⚠ ${clashes} clash${clashes > 1 ? 'es' : ''}` : '';
    addTag(new T.Vector3(w.x, .4, z1), `${w.id} · ${w.title}${note}`, 'work');
  }

  // ------------------------------------------------------------------ effects
  function points(n, color, size, opacity = 1, additive = true) {
    const g = new T.BufferGeometry();
    g.setAttribute('position', new T.Float32BufferAttribute(new Float32Array(n * 3), 3));
    const m = new T.PointsMaterial({ color, size, map: glowTex, transparent: true, opacity, depthWrite: false, blending: additive ? T.AdditiveBlending : T.NormalBlending, sizeAttenuation: true });
    const p = new T.Points(g, m); p.frustumCulled = false; root.add(p); return p;
  }
  function effects(half, L, FLOOR, topHalf, floorHalf, runs, ds, ss) {
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
    // 1. excavation reveal: the road over the cut lifts away in a puff of dust
    if (!still) {
      const lid = new T.Mesh(new T.BoxGeometry(topHalf * 2, .5, L), mat({ map: repeatClone(asphaltTex, 2, 3), roughness: .9, transparent: true }));
      lid.position.set(0, -.2, -L / 2); root.add(lid);
      const dust = points(260, 0xC9B79C, .9, .85, false);
      const dp = dust.geometry.attributes.position, vel = [];
      const rr = rng(5);
      for (let i = 0; i < 260; i++) { dp.setXYZ(i, (rr() - .5) * topHalf * 2, 0, -rr() * L); vel.push([(rr() - .5) * 3, 2 + rr() * 5, (rr() - .5) * 3]); }
      let age = 0;
      fx.push((dt) => {
        age += dt;
        const k = Math.min(1, Math.max(0, (age - .25) / 1.2));
        lid.position.y = -.2 + k * k * 9; lid.material.opacity = 1 - k; lid.visible = k < 1;
        if (age < 3) {
          for (let i = 0; i < 260; i++) { dp.setXYZ(i, dp.getX(i) + vel[i][0] * dt, dp.getY(i) + vel[i][1] * dt * (age > .25 ? 1 : 0), dp.getZ(i) + vel[i][2] * dt); vel[i][1] -= dt * 2.2; }
          dp.needsUpdate = true; dust.material.opacity = Math.max(0, .85 * (1 - age / 3));
        } else dust.visible = false;
      });
    }
    // 2. flow along pipes; power and data pulses along ducts
    const flows = [];
    for (const ri of runs) {
      const spec = {
        water: { c: 0x9FE6FF, v: -2.4, gap: 1.4, s: .55 }, sewer: { c: 0xB9F28A, v: 1.6, gap: 1.8, s: .6 },
        storm: { c: 0xA8E6FF, v: 2.0, gap: 1.2, s: .7 }, gas: { c: 0xFFE27A, v: -1.2, gap: 2.2, s: .4 },
        electricity: { c: 0xFFF2A8, v: -9, gap: 4.5, s: .55 }, telecom: { c: 0xFFE9B0, v: 7, gap: 5.5, s: .45 }, fibre: { c: 0x7FF6FF, v: -12, gap: 3.5, s: .5 },
      }[ri.kind];
      if (!spec) continue;
      const len = ri.z0 - ri.z1;
      for (const [x, y] of ri.lanes) {
        const n = Math.max(2, Math.floor(len / spec.gap));
        const p = points(n, spec.c, spec.s, .95);
        flows.push({ p, n, x, y, z0: ri.z0, z1: ri.z1, len, v: spec.v, off: Math.random() * len });
      }
    }
    if (!still) fx.push((dt) => {
      for (const f of flows) {
        f.off = (f.off + f.v * dt + f.len * 100) % f.len;
        const a = f.p.geometry.attributes.position;
        for (let i = 0; i < f.n; i++) { const z = f.z0 - ((f.off + i * f.len / f.n) % f.len); a.setXYZ(i, f.x, f.y, z); }
        a.needsUpdate = true;
      }
    });
    else for (const f of flows) { const a = f.p.geometry.attributes.position; for (let i = 0; i < f.n; i++) a.setXYZ(i, f.x, f.y, f.z0 - i * f.len / f.n); a.needsUpdate = true; }
    // 3. digital-twin scan: a glowing slice that sweeps through the cut
    const scanGroup = new T.Group(); root.add(scanGroup);
    const sliceShape = new T.Shape();
    sliceShape.moveTo(-topHalf, 0); sliceShape.lineTo(topHalf, 0); sliceShape.lineTo(floorHalf, FLOOR); sliceShape.lineTo(-floorHalf, FLOOR); sliceShape.lineTo(-topHalf, 0);
    const slice = new T.Mesh(new T.ShapeGeometry(sliceShape), new T.MeshBasicMaterial({ color: 0x7FD8FF, transparent: true, opacity: .16, blending: T.AdditiveBlending, depthWrite: false, side: T.DoubleSide }));
    scanGroup.add(slice);
    const outline = new T.LineLoop(new T.BufferGeometry().setFromPoints([new T.Vector3(-topHalf, .3, 0), new T.Vector3(topHalf, .3, 0), new T.Vector3(floorHalf, FLOOR, 0), new T.Vector3(-floorHalf, FLOOR, 0)]),
      new T.LineBasicMaterial({ color: 0xD8F6FF, transparent: true, opacity: .95 }));
    scanGroup.add(outline);
    scanGroup.visible = false;
    if (!still) {
      let st = -1.4;
      fx.push((dt) => {
        st += dt;
        const cycle = 6.5, ph = ((st % cycle) + cycle) % cycle;
        const on = st > 0 && ph < 3.0;
        scanGroup.visible = on;
        if (on) { const k = ph / 3.0; scanGroup.position.z = -k * L; slice.material.opacity = .1 + .12 * Math.sin(k * Math.PI); }
      });
    }
    // 4. dust motes in the sunlit pit
    const motes = points(60, 0xFFE2B0, .05, .3, false);
    const mp = motes.geometry.attributes.position, seeds = [];
    const r2 = rng(17);
    for (let i = 0; i < 60; i++) { seeds.push([(r2() - .5) * floorHalf * 2, FLOOR + r2() * -FLOOR, -r2() * L, r2() * 6]); mp.setXYZ(i, ...seeds[i].slice(0, 3)); }
    if (!still) fx.push((dt, t) => {
      for (let i = 0; i < 60; i++) { const s = seeds[i]; mp.setXYZ(i, s[0] + Math.sin(t * .3 + s[3]) * .6, s[1] + ((t * .25 + s[3]) % 2) * .6, s[2] + Math.cos(t * .2 + s[3]) * .6); }
      mp.needsUpdate = true;
    });
  }

  // ------------------------------------------------------------------ moving traffic
  function traffic(world, half, L) {
    const still = matchMedia('(prefers-reduced-motion: reduce)').matches;
    const types = {
      bus: { geo: B.bus.geo, mat: B.bus.material, len: 11.5 },
      car: { geo: B.car.geo, mat: B.car.material, len: 4.3, cab: true },
      auto: { geo: B.auto.geo, mat: B.auto.material, len: 2.6, top: true },
    };
    const movers = [];
    const rr = rng(99);
    const mix = (name) => /Departure|Arrival|Depot/.test(name) ? ['bus', 'bus', 'bus', 'car', 'auto'] : /Concourse/.test(name) ? ['auto', 'auto', 'car', 'auto', 'bus'] :
      /Service/.test(name) ? ['car', 'auto'] : /HIGHWAY|SH/.test(name) ? ['car', 'car', 'bus', 'car'] : ['car', 'bus', 'auto', 'car'];
    const lanesOf = (rd, isHw) => {
      const r = clipZ(rd); if (!r) return [];
      const along = isHw ? (r.x1 - r.x0) > (r.z1 - r.z0) : !rd.alongZ;
      const out = [];
      if (!along) {
        const cx = (r.x0 + r.x1) / 2, hw = (r.x1 - r.x0) / 2;
        let z0 = Math.max(r.z0 + 2, -340), z1 = r.z1 - 2;
        if (rd.self) z1 = Math.min(z1, CUT.z0 - 9);
        if (z1 - z0 > 10) for (const s of [-.75, -.25, .25, .75]) out.push({ axis: 'z', fixed: cx + s * hw, a: z0, b: z1, dir: s > 0 ? -1 : 1 });
      } else {
        const cz = (r.z0 + r.z1) / 2, hd = (r.z1 - r.z0) / 2;
        if (cz > -2 || cz < -340) return [];
        const a = Math.max(r.x0 + 2, -170), b = Math.min(r.x1 - 2, 170);
        const blocked = cz > CUT.z0 - 2;   // crossing in front of the cut: keep off the pit
        for (const s of [-.6, .6]) out.push({ axis: 'x', fixed: cz + s * hd * .5, a, b, dir: s > 0 ? 1 : -1, avoid: blocked });
      }
      return out;
    };
    const roads = [...world.roads.map((rd) => ({ rd, isHw: false })), ...(world.highway ? [{ rd: { ...world.highway, name: 'SH 71A' }, isHw: true }] : [])];
    for (const { rd, isHw } of roads) {
      const m = mix(rd.name);
      for (const lane of lanesOf(rd, isHw)) {
        const span = lane.b - lane.a, n = Math.max(1, Math.min(6, Math.floor(span / 26)));
        for (let i = 0; i < n; i++) movers.push({ type: m[(rr() * m.length) | 0], lane, pos: lane.a + rr() * span, speed: (isHw ? 9 : 4) + rr() * 3, color: [0xD8DCDF, 0x2F4A7A, 0xE9ECEE, 0x8C9399, 0xA23B32, 0x3B4B5B, 0x6B7F5E][(rr() * 7) | 0], bus: BUS_COLS[(rr() * BUS_COLS.length) | 0] });
      }
    }
    const make = (type) => {
      const list = movers.filter((m) => m.type === type); if (!list.length) return null;
      const t = types[type];
      const im = new T.InstancedMesh(t.geo, t.mat, list.length); im.castShadow = true; im.frustumCulled = false; root.add(im);
      const c = new T.Color(); list.forEach((m, i) => im.setColorAt(i, c.set(type === 'bus' ? m.bus : type === 'car' ? m.color : 0xffffff)));
      const extra = t.cab ? new T.InstancedMesh(B.cab.geo, B.cab.material, list.length) : t.top ? new T.InstancedMesh(B.autoTop.geo, B.autoTop.material, list.length) : null;
      if (extra) { extra.frustumCulled = false; root.add(extra); }
      return { list, im, extra };
    };
    const groups = ['bus', 'car', 'auto'].map(make).filter(Boolean);
    const o = new T.Object3D();
    const place = () => {
      for (const g of groups) {
        g.list.forEach((m, i) => {
          const l = m.lane;
          let x = l.axis === 'z' ? l.fixed : m.pos, z = l.axis === 'z' ? m.pos : l.fixed;
          if (l.avoid && l.axis === 'x' && x > CUT.x0 - 3 && x < CUT.x1 + 3) z -= 200;   // hidden while crossing the cut
          o.position.set(x, .1, z);
          o.rotation.set(0, l.axis === 'z' ? 0 : Math.PI / 2, 0);
          o.updateMatrix(); g.im.setMatrixAt(i, o.matrix); if (g.extra) g.extra.setMatrixAt(i, o.matrix);
        });
        g.im.instanceMatrix.needsUpdate = true; if (g.extra) g.extra.instanceMatrix.needsUpdate = true;
      }
    };
    place();
    if (!still) fx.push((dt) => {
      for (const m of movers) {
        const l = m.lane;
        m.pos += m.speed * dt * l.dir;
        if (m.pos < l.a) m.pos = l.b; if (m.pos > l.b) m.pos = l.a;
      }
      place();
    });
  }

  // ------------------------------------------------------------------ camera + gestures
  const home = { target: new T.Vector3(0, -4, -10), dist: 38, az: 0, el: .58 };
  const view = { target: new T.Vector3(), dist: 38, az: 0, el: .58 };
  let fly = null;
  function resetView(intro) {
    const start = { target: home.target.clone(), dist: home.dist * 1.9, az: 0, el: 1.45 };
    if (intro && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      Object.assign(view, { target: start.target.clone(), dist: start.dist, az: start.az, el: start.el });
      fly = { t0: performance.now(), dur: 1500, from: start, to: { target: home.target.clone(), dist: home.dist, az: -.18, el: home.el } };
    } else {
      Object.assign(view, { target: home.target.clone(), dist: home.dist, az: -.18, el: home.el });
    }
  }
  function applyCamera() {
    const e = Math.max(.12, Math.min(1.5, view.el));
    camera.position.set(
      view.target.x + view.dist * Math.cos(e) * Math.sin(view.az),
      view.target.y + view.dist * Math.sin(e),
      view.target.z + view.dist * Math.cos(e) * Math.cos(view.az));
    camera.lookAt(view.target);
  }
  const pointers = new Map();
  let gesture = null, moved = 0;
  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    moved = 0; fly = null;
    if (pointers.size === 2) { const [a, b] = [...pointers.values()]; gesture = { pinch: Math.hypot(a.x - b.x, a.y - b.y), dist: view.dist }; }
    hideHint();
  });
  canvas.addEventListener('pointermove', (e) => {
    const p = pointers.get(e.pointerId); if (!p) return;
    const dx = e.clientX - p.x, dy = e.clientY - p.y;
    p.x = e.clientX; p.y = e.clientY; moved += Math.abs(dx) + Math.abs(dy);
    if (pointers.size === 1) {
      view.az = Math.max(-1.1, Math.min(1.1, view.az - dx * .006));
      view.el = Math.max(.18, Math.min(1.35, view.el + dy * .005));
    } else if (pointers.size === 2 && gesture) {
      const [a, b] = [...pointers.values()];
      const d = Math.hypot(a.x - b.x, a.y - b.y);
      view.dist = Math.max(12, Math.min(110, gesture.dist * gesture.pinch / Math.max(1, d)));
      if (view.dist >= 108) bridge({ type: 'zoomedOut' });
    }
  });
  const up = (e) => {
    const wasTap = pointers.size === 1 && moved < 8;
    pointers.delete(e.pointerId);
    if (pointers.size < 2) gesture = null;
    if (wasTap) pick(e.clientX, e.clientY);
  };
  canvas.addEventListener('pointerup', up);
  canvas.addEventListener('pointercancel', (e) => { pointers.delete(e.pointerId); gesture = null; });
  canvas.addEventListener('wheel', (e) => { e.preventDefault(); view.dist = Math.max(12, Math.min(90, view.dist * (1 + e.deltaY * .001))); }, { passive: false });

  const ray = new T.Raycaster();
  function pick(x, y) {
    const r = canvas.getBoundingClientRect();
    ray.setFromCamera(new T.Vector2((x - r.left) / r.width * 2 - 1, -(y - r.top) / r.height * 2 + 1), camera);
    const hit = ray.intersectObjects(pickables, false)[0];
    if (hit) select(hit.object.userData.id); else select(null);
  }

  // ------------------------------------------------------------------ selection card
  const card = document.getElementById('card');
  function select(id) {
    selectedId = id;
    for (const m of pickables) {
      const on = id && m.userData.id === id;
      if (m.material && m.material.emissive) m.material.emissive.setHex(on ? 0x5A4A10 : 0x000000);
      m.userData.sel = on;
    }
    for (const a of anchors) a.el.classList.toggle('sel', !!id && a.id === id);
    const a = id && data && data.assets.find((x) => x.id === id);
    if (!a) { card.classList.remove('open'); return; }
    const k = KIND[a.kind] || KIND.water;
    document.getElementById('ck').textContent = `${a.id} · ${(a.owner || k.name).toUpperCase()}`;
    document.getElementById('ch').textContent = `${k.name}${a.crossing ? ' service connection' : ''}`;
    const rows = [['Size', a.size], ['Material', a.material], ['Depth', `${a.depth.toFixed(2)} m`], ['Installed', a.installYear], ['Record', a.label]];
    document.getElementById('cd').innerHTML = rows.filter((r) => r[1] !== undefined && r[1] !== null && r[1] !== '').map((r) => `<dt>${r[0]}</dt><dd>${r[1]}</dd>`).join('');
    card.classList.add('open');
    hideHint();
    bridge({ type: 'select', id });
  }
  document.getElementById('cclose').onclick = () => select(null);
  document.getElementById('copen').onclick = () => selectedId && bridge({ type: 'open', id: selectedId });
  document.getElementById('b2d').onclick = () => bridge({ type: 'close' });
  const hint = document.getElementById('hint');
  function hideHint() { hint.style.opacity = '0'; }

  // ------------------------------------------------------------------ labels layout
  const svg = document.getElementById('lines');
  function layoutLabels() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    let lines = '';
    const pipeTags = [];
    const occupied = [];
    const free = (b) => !occupied.some((o) => b.x < o.x + o.w + 5 && b.x + b.w + 5 > o.x && b.y < o.y + o.h + 4 && b.y + b.h + 4 > o.y);
    for (const a of anchors) {
      const p = a.pos.clone().project(camera);
      const sx = (p.x + 1) / 2 * w, sy = (1 - p.y) / 2 * h;
      const visible = p.z < 1 && sx > -40 && sx < w + 40 && sy > -40 && sy < h + 40;
      a.el.style.display = visible ? '' : 'none';
      if (!visible) continue;
      if (a.kind === 'pipe') { pipeTags.push({ a, sx, sy }); continue; }
      const ew = a.el.offsetWidth, eh = a.el.offsetHeight;
      const top = a.kind === 'twin' ? 0 : 118;
      const x = Math.max(6, Math.min(w - ew - 6, sx - ew / 2));
      let y = Math.max(top, sy - eh / 2);
      // Work and place tags that would sit on each other stack upwards.
      for (let i = 0; i < 4 && !free({ x, y, w: ew, h: eh }); i++) y -= eh + 6;
      occupied.push({ x, y, w: ew, h: eh });
      a.el.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
    }
    // Pipe tags: staggered rows below each pipe end, ordered by screen x so leaders never cross.
    pipeTags.sort((p, q) => p.sx - q.sx);
    const bottomLimit = h - (card.classList.contains('open') ? 230 : 70);
    pipeTags.forEach((t) => {
      const ew = t.a.el.offsetWidth, eh = t.a.el.offsetHeight;
      const clampX = (v) => Math.max(6, Math.min(w - ew - 6, v));
      const tries = [];
      for (let row = 0; row < 4; row++) for (const dx of [0, -.6, .6]) tries.push([clampX(t.sx - ew / 2 + dx * ew), t.sy + 30 + row * (eh + 6)]);
      for (let row = 0; row < 3; row++) for (const dx of [0, -.6, .6]) tries.push([clampX(t.sx - ew / 2 + dx * ew), t.sy - 30 - eh - row * (eh + 6)]);
      let x = tries[0][0], y = tries[0][1];
      for (const [tx, ty] of tries) {
        const yy = Math.max(70, Math.min(bottomLimit - eh, ty));
        if (free({ x: tx, y: yy, w: ew, h: eh })) { x = tx; y = yy; break; }
      }
      occupied.push({ x, y, w: ew, h: eh });
      t.a.el.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px)`;
      const ax = Math.max(x + 8, Math.min(x + ew - 8, t.sx));
      const ay = y > t.sy ? y : y + eh;
      lines += `<line x1="${t.sx.toFixed(1)}" y1="${t.sy.toFixed(1)}" x2="${ax.toFixed(1)}" y2="${ay.toFixed(1)}" stroke="#fff" stroke-width="1.6"/>` +
               `<circle cx="${t.sx.toFixed(1)}" cy="${t.sy.toFixed(1)}" r="3.6" fill="#fff"/>`;
    });
    svg.innerHTML = lines;
  }

  // ------------------------------------------------------------------ loop
  function resize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h, false); camera.aspect = w / h; camera.fov = w < h ? 50 : 40; camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', resize);
  const ease = (t) => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  let lastLayout = 0, lastFrame = 0, clock = 0;
  function frame(now) {
    const dt = Math.min(.05, lastFrame ? (now - lastFrame) / 1000 : 0); lastFrame = now; clock += dt;
    for (const f of fx) f(dt, clock);
    if (fly) {
      const t = Math.min(1, (now - fly.t0) / fly.dur), k = ease(t);
      view.target.lerpVectors(fly.from.target, fly.to.target, k);
      view.dist = fly.from.dist + (fly.to.dist - fly.from.dist) * k;
      view.az = fly.from.az + (fly.to.az - fly.from.az) * k;
      view.el = fly.from.el + (fly.to.el - fly.from.el) * k;
      if (t >= 1) fly = null;
    }
    applyCamera();
    renderer.render(scene, camera);
    if (now - lastLayout > 30) { layoutLabels(); lastLayout = now; }
    requestAnimationFrame(frame);
  }

  // ------------------------------------------------------------------ public API
  window.samanvayLoad = function (d) {
    try {
      build(typeof d === 'string' ? JSON.parse(d) : d);
      const l = document.getElementById('loading'); l.style.opacity = '0'; setTimeout(() => l.remove(), 600);
      if (d.focusId) setTimeout(() => select(d.focusId), 1600);
      bridge({ type: 'ready' });
    } catch (e) {
      document.getElementById('loading').textContent = 'The 3D view could not be drawn on this device: ' + e.message;
      bridge({ type: 'error', message: String(e && e.message || e) });
    }
  };
  window.samanvaySkipIntro = function () { fly = null; resetView(false); };

  buildEnvironment();
  resize();
  requestAnimationFrame(frame);
  bridge({ type: 'boot' });
  // Opened directly (not from the app): show the built-in sample.
  setTimeout(() => { if (!data && window.SAMANVAY_SAMPLE) window.samanvayLoad(window.SAMANVAY_SAMPLE); }, 300);
})();
