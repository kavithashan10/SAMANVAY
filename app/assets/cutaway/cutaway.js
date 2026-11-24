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

  // ------------------------------------------------------------------ scene state
  let envMap = null;
  let root = null;
  const pickables = [];         // meshes that can be tapped
  const anchors = [];           // { pos: Vector3, el, kind: 'pipe'|'place'|'work'|'twin', id }
  let data = null;
  let selectedId = null;

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
    // a,b,c,d: [x,y,z] in order around the face; UVs from metres along the edges.
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

  // ------------------------------------------------------------------ build
  function build(d) {
    data = d;
    if (root) { scene.remove(root); root.traverse((o) => { if (o.geometry) o.geometry.dispose(); }); }
    pickables.length = 0; anchors.length = 0;
    document.getElementById('labels').innerHTML = '';
    root = new T.Group(); scene.add(root);

    // The schematic road is wide; across-road distances are drawn at crossScale so the
    // whole cut fits a phone screen. Depths and sizes are exaggerated; the card shows true values.
    const cs = d.crossScale || .55;
    d.assets.forEach((a) => { if (a.x !== undefined) a.x *= cs; if (a.x0 !== undefined) a.x0 *= cs; if (a.x1 !== undefined) a.x1 *= cs; });
    (d.works || []).forEach((w) => { if (w.x !== undefined) w.x *= cs; });
    const W = (d.width || 30) * cs, half = W / 2, L = d.length || 24;
    const ds = d.depthScale || 2.5, ss = d.sizeScale || 2.5;
    const maxDepth = Math.max(2.2, ...d.assets.filter((a) => !a.crossing).map((a) => a.depth + (a.sizeMm || 300) / 1000 * ss));
    const FLOOR = -(maxDepth * ds + 1.4);
    const BASE = FLOOR - 16;
    const topHalf = half + .3, floorHalf = half - 2.5;
    const FAR = 300;
    document.getElementById('t1').textContent = `Underground · ${d.road}`;
    document.getElementById('t2').textContent = 'Sample records · drawn larger than life · not for excavation';

    // --- far ground (aerial imagery look) and the bus stand surroundings
    // Nothing is drawn in front of the cut (z > 0) and the ground stops at the pit rim.
    const aerial = aerialTex(41); aerial.repeat.set(4, 6);
    const aerialM = mat({ map: aerial, roughness: 1 });
    plane(300, FAR - L, aerialM, 0, -0.05, -(L + FAR) / 2);
    for (const s of [-1, 1]) {
      const sideA = aerial.clone(); sideA.needsUpdate = true; sideA.repeat.set(2, .5);
      plane(150 - topHalf, L, mat({ map: sideA, roughness: 1 }), s * (topHalf + (150 - topHalf) / 2), -0.05, -L / 2);
    }
    const conc = mat({ map: repeatClone(concreteTex, 4, 40), roughness: .95 });
    plane(28, FAR, conc, -(half + 3.5 + 14), 0.02, -FAR / 2);
    plane(28, FAR, conc, half + 3.5 + 14, 0.02, -FAR / 2);
    // footpaths with kerbs, grass strip
    const foot = mat({ map: repeatClone(concreteTex, 1, 60), roughness: .9 });
    for (const s of [-1, 1]) {
      box(3.2, .22, FAR, foot, s * (half + 2.1), .11, -FAR / 2, false);
      box(.3, .3, FAR, mat({ color: 0xBFC4C8 }), s * (half + .35), .15, -FAR / 2, false);
      plane(1.4, FAR - L, mat({ map: repeatClone(grassTex, 1, 60) }), s * (half + 4.4), .03, -(L + FAR) / 2);
    }
    sideDressing(-1, d.left || 'platform', d.leftName, half, L, FAR);
    sideDressing(1, d.right || 'commons', d.rightName, half, L, FAR);
    trees(half, L, FAR);

    // --- road slab beyond the cut: asphalt over base course (visible at the cut)
    const asphalt = mat({ map: repeatClone(asphaltTex, W / 8, (FAR - L) / 8), roughness: .92 });
    box(W, .45, FAR - L, asphalt, 0, -.225 + .02, -(L + FAR) / 2);
    box(W + 4, 1.4, FAR - L, mat({ map: repeatClone(gravelTex, 6, 2), roughness: 1 }), 0, -1.15, -(L + FAR) / 2, false);
    markings(half, L, FAR);
    traffic(half, L, FAR);

    // --- the cut: pit walls, floor, back wall, cut face with strata
    const soilM = (rx, ry) => mat({ map: repeatClone(soilTex, rx, ry), roughness: 1 });
    // back wall under the road slab (z = -L)
    quad([-topHalf, -1.85, -L], [topHalf, -1.85, -L], [floorHalf, FLOOR, -L], [-floorHalf, FLOOR, -L], soilM(.1, 1 / Math.max(1, -FLOOR)), 1);
    // floor
    quad([-floorHalf, FLOOR, 0], [floorHalf, FLOOR, 0], [floorHalf, FLOOR, -L], [-floorHalf, FLOOR, -L], mat({ map: repeatClone(floorTex, .12, .12), roughness: 1 }), 1);
    // sloped side walls
    quad([-topHalf, 0, -L], [-topHalf, 0, 0], [-floorHalf, FLOOR, 0], [-floorHalf, FLOOR, -L], soilM(.08, 1 / Math.max(1, -FLOOR)), 1);
    quad([topHalf, 0, 0], [topHalf, 0, -L], [floorHalf, FLOOR, -L], [floorHalf, FLOOR, 0], soilM(.08, 1 / Math.max(1, -FLOOR)), 1);
    // surface strips between the cut and the footpaths along the open part
    // cut face: everything at z = 0 outside the pit opening, as one shape with a hole
    const faceW = topHalf + 18;
    const shape = new T.Shape();
    shape.moveTo(-faceW, 0); shape.lineTo(faceW, 0); shape.lineTo(faceW, BASE); shape.lineTo(-faceW, BASE); shape.lineTo(-faceW, 0);
    const hole = new T.Path();
    hole.moveTo(-topHalf, 0); hole.lineTo(-floorHalf, FLOOR); hole.lineTo(floorHalf, FLOOR); hole.lineTo(topHalf, 0); hole.lineTo(-topHalf, 0);
    shape.holes.push(hole);
    const fg = new T.ShapeGeometry(shape);
    const fuv = fg.attributes.uv;
    for (let i = 0; i < fuv.count; i++) fuv.setXY(i, (fg.attributes.position.getX(i) + faceW) / (2 * faceW) * 3, 1 + fg.attributes.position.getY(i) / -BASE);
    const rock = strataTexture(FLOOR, BASE);
    const face = new T.Mesh(fg, mat({ map: rock, roughness: 1 }));
    face.receiveShadow = true; root.add(face);
    // road cross-section at the face (asphalt + base) beside the opening, and kerb lines along the rim
    for (const s of [-1, 1]) {
      box(faceW - topHalf, .45, .3, asphalt, s * (topHalf + (faceW - topHalf) / 2), -.2, -.15, false);
    }

    // --- utilities
    const runs = d.assets.filter((a) => !a.crossing);
    const crossings = d.assets.filter((a) => a.crossing);
    for (const a of crossings) crossingPipe(a, ds, ss, floorHalf, L);
    for (const a of runs) utility(a, ds, ss, L);

    // --- planned works on this stretch
    for (const w of d.works || []) workVolume(w, ds, L);

    // --- glass digital-twin volume
    const gx = topHalf + 2.5;
    const gb = new T.BoxGeometry(gx * 2, -FLOOR + 3.2, L);
    const edges = new T.LineSegments(new T.EdgesGeometry(gb), new T.LineBasicMaterial({ color: 0xBFE6FF, transparent: true, opacity: .85 }));
    edges.position.set(0, (FLOOR - 2) / 2 + .9 - .6, -L / 2); root.add(edges);
    const glass = new T.Mesh(new T.PlaneGeometry(gx * 2, L), new T.MeshBasicMaterial({ color: 0x9FD3F5, transparent: true, opacity: .1, depthWrite: false }));
    glass.rotation.x = -Math.PI / 2; glass.position.set(0, .9, -L / 2); root.add(glass);
    addTag(new T.Vector3(0, .9, 0), 'SAMANVAY GEO-TWIN', 'twin');

    // camera framing for this stretch
    home.target.set(0, FLOOR * .42, -L * .42);
    home.dist = Math.max(36, (W + 8) * 2.2);
    resetView(true);
  }

  // --------------------------------------------------------------- utilities
  function radiusOf(a, ss) { return Math.max(.14, (a.sizeMm || 150) / 2000 * ss); }
  function pipeMaterial(a, len) {
    const k = KIND[a.kind] || KIND.water;
    const map = labelTexture(`${k.text}  ·  ${a.size || ''}`, hex(k.color), Math.max(1, Math.round(len / 7)));
    return new T.MeshStandardMaterial({ map, color: 0xffffff, roughness: a.kind === 'storm' ? .9 : .32, metalness: .05, envMap, envMapIntensity: .35 });
  }
  function tube(a, x, y, r, len, material, group, z0 = 0) {
    const g = new T.CylinderGeometry(r, r, len, 48, 1, true);
    g.rotateX(Math.PI / 2);
    const m = new T.Mesh(g, material); m.position.set(x, y, z0 - len / 2); m.castShadow = true; m.receiveShadow = true;
    group.add(m);
    const inner = new T.Mesh(g.clone().scale(.9, .9, 1), new T.MeshStandardMaterial({ color: 0x15181B, roughness: 1, side: T.BackSide }));
    inner.position.copy(m.position); group.add(inner);
    const ring = new T.Mesh(new T.RingGeometry(r * .88, r, 48), new T.MeshStandardMaterial({ color: material.color, map: null, roughness: .5 }));
    ring.material.color = new T.Color((KIND[a.kind] || KIND.water).color).multiplyScalar(.92);
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
    let top = y, tagX = a.x;
    if (a.kind === 'storm') {
      // precast box culvert with a round barrel
      const r = radiusOf(a, ss), s = r * 1.45;
      const sh = new T.Shape(); sh.moveTo(-s, -s); sh.lineTo(s, -s); sh.lineTo(s, s); sh.lineTo(-s, s); sh.lineTo(-s, -s);
      const h = new T.Path(); h.absarc(0, 0, r, 0, Math.PI * 2, true); sh.holes.push(h);
      const g = new T.ExtrudeGeometry(sh, { depth: len, bevelEnabled: true, bevelSize: .05, bevelThickness: .05, bevelSegments: 1, curveSegments: 48 });
      const cm = new T.MeshStandardMaterial({ map: repeatClone(concreteTex, .3, .3), color: 0xEDEDE8, roughness: .95 });
      const m = new T.Mesh(g, cm); m.position.set(a.x, y, z0 - len); m.castShadow = m.receiveShadow = true; group.add(m);
      const inner = new T.Mesh(new T.CylinderGeometry(r, r, len, 48, 1, true).rotateX(Math.PI / 2), new T.MeshStandardMaterial({ color: 0x101316, side: T.BackSide, roughness: 1 }));
      inner.position.set(a.x, y, z0 - len / 2); group.add(inner);
      m.userData.id = a.id; pickables.push(m);
      top = y + s;
    } else if (a.kind === 'electricity' || a.kind === 'telecom') {
      // duct bank: a grid of conduits
      const rows = a.kind === 'electricity' ? 3 : 4, cols = 3;
      const r = a.kind === 'electricity' ? .2 * ss / 2.5 * 1.25 : .18 * ss / 2.5 * 1.25;
      const material = pipeMaterial(a, len);
      for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
        tube(a, a.x + (j - (cols - 1) / 2) * r * 2.12, y + ((rows - 1) / 2 - i) * r * 2.12, r, len, material, group, z0);
      }
      top = y + rows * r * 1.06;
    } else if (a.kind === 'fibre') {
      const r = Math.max(.2, radiusOf(a, ss) * .8), material = pipeMaterial(a, len);
      tube(a, a.x - r * 1.15, y, r, len, material, group, z0);
      tube(a, a.x + r * 1.15, y, r, len, material, group, z0);
      top = y + r;
    } else {
      const r = radiusOf(a, ss);
      tube(a, a.x, y, r, len, pipeMaterial(a, len), group, z0);
      top = y + r;
    }
    const sub = [a.size, `${a.depth.toFixed(1)} m`].filter(Boolean).join(' · ');
    if (!a.noTag) addTag(new T.Vector3(tagX, top, z0), `<b>${k.tag.toUpperCase()}</b><span>${sub}</span>`, 'pipe', a.id);
    void k;
  }
  function crossingPipe(a, ds, ss, floorHalf, L) {
    const k = KIND[a.kind] || KIND.water;
    const z = Math.max(-L + 1, Math.min(-1, a.z ?? -L / 2));
    const x0 = Math.max(-floorHalf, a.x0 ?? -floorHalf), x1 = Math.min(floorHalf, a.x1 ?? floorHalf);
    const r = Math.max(.1, (a.sizeMm || 63) / 2000 * ss);
    const g = new T.CylinderGeometry(r, r, Math.abs(x1 - x0), 24); g.rotateZ(Math.PI / 2);
    const m = new T.Mesh(g, new T.MeshStandardMaterial({ color: k.color, roughness: .45 }));
    m.position.set((x0 + x1) / 2, -a.depth * ds, z); m.castShadow = true; root.add(m);
    m.userData.id = a.id; pickables.push(m);
  }
  function workVolume(w, ds, L) {
    const z0 = Math.min(0, w.z0 ?? 0), z1 = Math.max(-L, w.z1 ?? -L);
    const len = Math.max(.5, z0 - z1), depth = (w.depth || 1.5) * ds, width = Math.max(1.2, (w.width || .6) * 2.6);
    const g = new T.BoxGeometry(width, depth, len);
    const m = new T.Mesh(g, new T.MeshBasicMaterial({ color: 0x2A72DE, transparent: true, opacity: .13, depthWrite: false }));
    m.position.set(w.x, -depth / 2, z0 - len / 2); root.add(m);
    const e = new T.LineSegments(new T.EdgesGeometry(g), new T.LineDashedMaterial({ color: 0x2A72DE, dashSize: .7, gapSize: .45 }));
    e.computeLineDistances(); e.position.copy(m.position); root.add(e);
    addTag(new T.Vector3(w.x, .4, z1), `${w.id} · ${w.title}`, 'work');
  }

  // --------------------------------------------------------------- surface dressing
  function markings(half, L, FAR) {
    const white = new T.MeshBasicMaterial({ color: 0xF2F2EE }), yellow = new T.MeshBasicMaterial({ color: 0xF0BE2C });
    const add = (x, w, z0, z1, m) => { const p = new T.Mesh(new T.PlaneGeometry(w, z0 - z1), m); p.rotation.x = -Math.PI / 2; p.position.set(x, .035, (z0 + z1) / 2); root.add(p); };
    for (const s of [-1, 1]) add(s * (half - .7), .18, -L, -FAR, white);
    for (const x of [-.18, .18]) add(x, .14, -L, -FAR, yellow);
    for (const x of [-half / 2, half / 2]) for (let z = -L - 1; z > -FAR; z -= 9) add(x, .16, z, z - 4, white);
    // zebra crossing just beyond the cut
    for (let i = 0; i < 9; i++) add(-half + 2 + i * (half * 2 - 4) / 8, .7, -L - 3, -L - 7, white);
  }
  function bus(x, z, color, rot = 0) {
    const g = new T.Group();
    const body = new T.MeshStandardMaterial({ color, roughness: .45, metalness: .1, envMap, envMapIntensity: .4 });
    const glassM = new T.MeshStandardMaterial({ color: 0x1B2733, roughness: .15, metalness: .3 });
    const b = new T.Mesh(new T.BoxGeometry(2.55, 2.9, 11.5), body); b.position.y = 1.85; b.castShadow = b.receiveShadow = true; g.add(b);
    const roof = new T.Mesh(new T.BoxGeometry(2.4, .12, 10.8), new T.MeshStandardMaterial({ color: 0xEEF1F3, roughness: .6 })); roof.position.y = 3.35; g.add(roof);
    for (const s of [-1, 1]) { const w = new T.Mesh(new T.BoxGeometry(.04, .9, 10.2), glassM); w.position.set(s * 1.28, 2.45, 0); g.add(w); }
    const ws = new T.Mesh(new T.BoxGeometry(2.3, 1.3, .05), glassM); ws.position.set(0, 2.3, 5.76); g.add(ws);
    const bk = new T.Mesh(new T.BoxGeometry(2.3, .9, .05), glassM); bk.position.set(0, 2.6, -5.76); g.add(bk);
    const wheelM = new T.MeshStandardMaterial({ color: 0x1A1A1A, roughness: .9 });
    for (const sx of [-1.2, 1.2]) for (const sz of [-3.8, 3.8]) { const wh = new T.Mesh(new T.CylinderGeometry(.5, .5, .3, 18).rotateZ(Math.PI / 2), wheelM); wh.position.set(sx, .5, sz); g.add(wh); }
    g.position.set(x, 0, z); g.rotation.y = rot; root.add(g); return g;
  }
  function car(x, z, color) {
    const g = new T.Group();
    const body = new T.MeshStandardMaterial({ color, roughness: .3, metalness: .4, envMap, envMapIntensity: .6 });
    const glassM = new T.MeshStandardMaterial({ color: 0x1F2B36, roughness: .1, metalness: .4 });
    const b = new T.Mesh(new T.BoxGeometry(1.8, .75, 4.3), body); b.position.y = .62; b.castShadow = true; g.add(b);
    const c = new T.Mesh(new T.BoxGeometry(1.55, .6, 2.2), glassM); c.position.set(0, 1.25, -.15); c.castShadow = true; g.add(c);
    const top = new T.Mesh(new T.BoxGeometry(1.5, .06, 1.9), body); top.position.set(0, 1.56, -.15); g.add(top);
    const lamp = new T.MeshBasicMaterial({ color: 0xC0392B });
    for (const s of [-.62, .62]) { const l = new T.Mesh(new T.BoxGeometry(.4, .14, .04), lamp); l.position.set(s, .78, 2.16); g.add(l); }
    g.position.set(x, 0, z); g.rotation.y = Math.PI; root.add(g);
  }
  function auto(x, z) {
    const g = new T.Group();
    const b = new T.Mesh(new T.BoxGeometry(1.3, .9, 2.6), new T.MeshStandardMaterial({ color: 0xE8BE1E, roughness: .5 })); b.position.y = .75; b.castShadow = true; g.add(b);
    const t = new T.Mesh(new T.BoxGeometry(1.35, .12, 2.2), new T.MeshStandardMaterial({ color: 0x26452D, roughness: .7 })); t.position.set(0, 1.55, -.1); g.add(t);
    const f = new T.Mesh(new T.BoxGeometry(1.2, .65, 2.0), new T.MeshStandardMaterial({ color: 0x26452D, roughness: .7 })); f.position.set(0, 1.2, -.1); g.add(f);
    g.position.set(x, 0, z); root.add(g);
  }
  function traffic(half, L, FAR) {
    const cols = [0xD8DCDF, 0x2F4A7A, 0xE9ECEE, 0x8C9399, 0x6B7F5E, 0xBFC5CA, 0xA23B32, 0x3B4B5B];
    const r = rng(77);
    for (let i = 0; i < 16; i++) {
      const lane = [-half * .75, -half * .25, half * .25, half * .75][(r() * 4) | 0];
      const z = -L - 8 - r() * 160;
      if (r() < .18) auto(lane, z); else car(lane, z, cols[(r() * cols.length) | 0]);
    }
    bus(-half * .75, -L - 52, 0x2C7A6B);
  }
  function sideDressing(s, kind, name, half, L, FAR) {
    const x0 = s * (half + 5.5), dir = s;
    const r = rng(kind.length * 31 + (s > 0 ? 7 : 3));
    const busCols = [0xB4412D, 0x2C7A6B, 0xCF8A1E, 0x3D5F99];
    if (kind === 'platform' || kind === 'bays') {
      // passenger island with canopy, buses in angled bays
      const island = new T.Mesh(new T.BoxGeometry(4.2, .3, FAR - L - 4), mat({ map: repeatClone(concreteTex, 1, 40), color: 0xF1E6D0 }));
      island.position.set(x0 + dir * 11.5, .15, -(L + FAR) / 2); island.receiveShadow = true; root.add(island);
      const edge = new T.Mesh(new T.BoxGeometry(.25, .31, FAR - L - 4), new T.MeshBasicMaterial({ color: 0xF0BE2C }));
      edge.position.set(x0 + dir * 9.3, .16, -(L + FAR) / 2); root.add(edge);
      const canopy = new T.Mesh(new T.BoxGeometry(5, .25, FAR - L - 30), new T.MeshStandardMaterial({ color: 0xE9ECEE, roughness: .5 }));
      canopy.position.set(x0 + dir * 11.5, 4.2, -(L + FAR) / 2 - 10); canopy.castShadow = true; root.add(canopy);
      for (let z = -L - 8; z > -FAR + 20; z -= 12) { const p = new T.Mesh(new T.CylinderGeometry(.12, .12, 4, 10), mat({ color: 0x6B7480 })); p.position.set(x0 + dir * 11.5, 2.1, z); root.add(p); }
      for (let i = 0, z = -L - 6; z > -FAR + 40; i++, z -= 9) {
        if (r() < .25) continue;
        bus(x0 + dir * 5.5, z - 6, busCols[i % 4], dir * .5);
      }
    } else if (kind === 'commons' || kind === 'admin' || kind === 'concourse' || kind === 'depot') {
      const awn = [0xC8553D, 0x2C7A6B, 0xD9A43A, 0x3D5F99];
      for (let i = 0, z = -L - 1; z > -FAR + 20; i++, z -= 8) {
        const shop = new T.Mesh(new T.BoxGeometry(9, 3.8, 7.4), mat({ color: kind === 'depot' ? 0xC5CCD3 : 0xEFE4CF, roughness: .9 }));
        shop.position.set(x0 + dir * 9.5, 1.9, z - 3.7); shop.castShadow = shop.receiveShadow = true; root.add(shop);
        const front = new T.Mesh(new T.PlaneGeometry(6.6, 2.4), new T.MeshStandardMaterial({ color: 0x3B4650, roughness: .3 }));
        front.position.set(x0 + dir * 4.99, 1.4, z - 3.7); front.rotation.y = -dir * Math.PI / 2; root.add(front);
        const aw = new T.Mesh(new T.BoxGeometry(1.6, .12, 7.2), new T.MeshStandardMaterial({ color: awn[i % 4], roughness: .7 }));
        aw.position.set(x0 + dir * 4.3, 3.0, z - 3.7); aw.rotation.z = dir * .35; aw.castShadow = true; root.add(aw);
      }
    } else {
      // parking: autos and two-wheelers in rows
      for (let z = -L - 3; z > -FAR + 30; z -= 3.2) { if (r() < .35) continue; auto(x0 + dir * (4 + r() * 10), z); }
    }
    // bus shelter on the footpath near the cut
    if (s > 0) {
      const sx = s * (half + 2.1), sz = -L - 9;
      for (const dz of [-1.8, 1.8]) for (const dx of [-1, 1]) { const p = new T.Mesh(new T.CylinderGeometry(.06, .06, 2.6, 8), mat({ color: 0x4A5560 })); p.position.set(sx + dx, 1.3, sz + dz); root.add(p); }
      const roof = new T.Mesh(new T.BoxGeometry(2.6, .1, 4.4), new T.MeshStandardMaterial({ color: 0x8FC9EA, transparent: true, opacity: .75, roughness: .1 }));
      roof.position.set(sx, 2.65, sz); root.add(roof);
      addTag(new T.Vector3(sx, 3.2, sz), 'BUS SHELTER', 'place');
    }
    if (name) addTag(new T.Vector3(x0 + dir * 10, 6.5, -L - 30), name.toUpperCase(), 'place');
  }
  function trees(half, L, FAR) {
    const leaf = [0x4F6B3A, 0x5E7E44, 0x6E8C52], trunk = mat({ color: 0x6B4F35 });
    const r = rng(101);
    for (const s of [-1, 1]) {
      for (let z = -3; z > -FAR + 40; z -= 10 + r() * 6) {
        const x = s * (half + 28 + r() * 6);
        const t = new T.Mesh(new T.CylinderGeometry(.18, .25, 2.4, 8), trunk); t.position.set(x, 1.2, z); t.castShadow = true; root.add(t);
        const n = 3 + ((r() * 2) | 0);
        for (let i = 0; i < n; i++) {
          const b = new T.Mesh(new T.IcosahedronGeometry(1.5 + r() * 1.1, 1), mat({ color: leaf[(r() * 3) | 0], roughness: .9, flatShading: true }));
          b.position.set(x + (r() - .5) * 1.8, 3.1 + r() * 1.4, z + (r() - .5) * 1.8); b.castShadow = true; root.add(b);
        }
      }
    }
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
  let lastLayout = 0;
  function frame(now) {
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
