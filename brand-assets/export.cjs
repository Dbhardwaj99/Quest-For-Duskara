// Uses bundled sharp; adds no project dependency. Run --self-check before exporting.
const fs = require('node:fs/promises'), path = require('node:path'), assert = require('node:assert/strict');
let sharp;
try { sharp = require('sharp'); }
catch { sharp = require('/Users/aaa/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp'); }
const root = __dirname, png = { compressionLevel: 9, adaptiveFiltering: true };

async function transparent(input, flat = false, trim = true) {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  for (let i = 0; i < data.length; i += 4) {
    const [r, g, b] = data.subarray(i, i + 3);
    if (flat) {
      data[i + 3] = r * .2126 + g * .7152 + b * .0722 > 175 ? 255 : 0;
      data[i] = 242; data[i + 1] = 232; data[i + 2] = 209;
    } else if (r > 170 && b > 170 && g < 150 && Math.min(r, b) - g > 80) data[i + 3] = 0;
  }
  const image = sharp(data, { raw: info });
  return (trim ? image.trim({ background: '#00000000', threshold: 5 }) : image).png(png).toBuffer();
}

async function logo(input, width, height, flat = false) {
  const content = await sharp(await transparent(input, flat)).resize(Math.round(width * .9), Math.round(height * .9), { fit: 'inside' }).png(png).toBuffer();
  return sharp({ create: { width, height, channels: 4, background: '#00000000' } }).composite([{ input: content, gravity: 'centre' }]).png(png).toBuffer();
}

// Trace generated lettering, including counters. No substituted typeface or embedded raster.
async function vectorize(input) {
  const { data, info } = await sharp(input).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info, edges = new Map();
  const filled = (x, y) => x >= 0 && y >= 0 && x < w && y < h && data[(y * w + x) * 4 + 3] > 127;
  const add = (x, y, nx, ny) => { const key = y * (w + 1) + x, list = edges.get(key) || []; list.push(ny * (w + 1) + nx); edges.set(key, list); };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (filled(x, y)) {
    if (!filled(x, y - 1)) add(x, y, x + 1, y);
    if (!filled(x + 1, y)) add(x + 1, y, x + 1, y + 1);
    if (!filled(x, y + 1)) add(x + 1, y + 1, x, y + 1);
    if (!filled(x - 1, y)) add(x, y + 1, x, y);
  }
  const xy = p => [p % (w + 1), Math.floor(p / (w + 1))], paths = [];
  while (edges.size) {
    const start = edges.keys().next().value, points = [xy(start)]; let p = start;
    do {
      const next = edges.get(p); assert(next && next.length, 'Broken vector contour');
      const q = next.pop(); if (!next.length) edges.delete(p);
      p = q; points.push(xy(p));
    } while (p !== start);
    const simple = points.filter((point, i) => i === 0 || i === points.length - 1 || (point[0] - points[i - 1][0]) * (points[i + 1][1] - point[1]) !== (point[1] - points[i - 1][1]) * (points[i + 1][0] - point[0]));
    paths.push(`M${simple.map(p => p.join(' ')).join('L')}Z`);
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="Quest for Duskara"><path fill="#F2E8D1" fill-rule="evenodd" d="${paths.join('')}"/></svg>\n`;
}

async function exportJob(job) {
  const input = path.resolve(root, job.input), output = path.resolve(root, job.output);
  assert(output.startsWith(root + path.sep), 'Output must be inside brand-assets');
  assert(Number.isInteger(job.width) && job.width > 0 && Number.isInteger(job.height) && job.height > 0, 'Positive integer dimensions required');
  await fs.mkdir(path.dirname(output), { recursive: true });
  if (job.kind === 'logo' || job.kind === 'flat') {
    const result = await logo(input, job.width, job.height, job.kind === 'flat');
    await fs.writeFile(output, result);
    await sharp(result).resize(job.width / 2, job.height / 2).png(png).toFile(output.replace(/\.png$/, '-50pct.png'));
    if (job.kind === 'flat') {
      await fs.writeFile(output.replace(/\.png$/, '.svg'), await vectorize(result));
      await sharp(result).flatten({ background: '#1B4A5E' }).removeAlpha().png(png).toFile(output.replace(/\.png$/, '-teal-preview.png'));
    }
  } else {
    let image = sharp(input).resize(job.width, job.height, { fit: job.fit || 'cover', position: job.position || 'centre' });
    if (job.logo) {
      const mark = await sharp(path.resolve(root, job.logo)).resize(job.logoWidth, job.logoHeight || null, { fit: 'inside' }).png(png).toBuffer();
      const metadata = await sharp(mark).metadata();
      assert(job.x >= 0 && job.y >= 0 && job.x + metadata.width <= job.width && job.y + metadata.height <= job.height, 'Logo must stay inside banner');
      image = sharp(await image.png(png).toBuffer()).composite([{ input: mark, left: job.x, top: job.y }]);
    }
    if (job.kind === 'emblem') {
      if (job.contentScale) {
        assert(job.contentScale > 0 && job.contentScale <= 1, 'Content scale must be inside (0, 1]');
        const content = await sharp(await transparent(input)).resize(Math.round(job.width * job.contentScale), Math.round(job.height * job.contentScale), { fit: 'inside' }).png(png).toBuffer();
        image = sharp({ create: { width: job.width, height: job.height, channels: 4, background: '#00000000' } }).composite([{ input: content, gravity: 'centre' }]);
      } else image = sharp(await transparent(input, false, false)).resize(job.width, job.height, { fit: 'contain', background: '#00000000' });
    }
    else image = image.toColourspace('srgb').flatten({ background: job.background || '#1B4A5E' }).removeAlpha();
    if (job.grayscale) {
      const { data, info } = await image.raw().toBuffer({ resolveWithObject: true });
      assert.equal(info.channels, 3, 'Grayscale normalization requires RGB');
      for (let i = 0; i < data.length; i += 3) {
        const luminance = Math.round(data[i] * .2126 + data[i + 1] * .7152 + data[i + 2] * .0722);
        data.fill(luminance < 4 ? 0 : luminance, i, i + 3);
      }
      image = sharp(data, { raw: info });
    }
    await image.png(png).toFile(output);
  }
  const info = await sharp(output).metadata();
  assert.equal(info.width, job.width); assert.equal(info.height, job.height);
  if (!['logo', 'flat', 'emblem'].includes(job.kind)) assert.equal(info.hasAlpha, false, 'Opaque exports must have no alpha');
  if (job.kind === 'icon') assert.equal(info.channels, 3, 'Icons must be RGB');
  return { file: job.output, width: info.width, height: info.height, alpha: info.hasAlpha, bytes: (await fs.stat(output)).size };
}

async function validate(planFile) {
  const jobs = JSON.parse(await fs.readFile(planFile, 'utf8')), results = [];
  for (const job of jobs) {
    const variants = [[job.output, job.width, job.height]];
    if (job.kind === 'logo' || job.kind === 'flat') variants.push([job.output.replace(/\.png$/, '-50pct.png'), job.width / 2, job.height / 2]);
    if (job.kind === 'flat') variants.push([job.output.replace(/\.png$/, '-teal-preview.png'), job.width, job.height], [job.output.replace(/\.png$/, '.svg'), job.width, job.height]);
    for (const [file, width, height] of variants) {
      const target = path.resolve(root, file), info = await sharp(target).metadata();
      assert.equal(info.width, width, file); assert.equal(info.height, height, file);
      assert.equal(info.hasAlpha, ['logo', 'flat', 'emblem'].includes(job.kind) && !file.includes('-teal-preview'), file);
      if (job.kind === 'icon') assert.equal(info.channels, 3, 'Icons must be RGB');
      if (job.grayscale) {
        const data = await sharp(target).raw().toBuffer();
        for (let i = 0; i < data.length; i += 3) assert(data[i] === data[i + 1] && data[i + 1] === data[i + 2], 'Tinted icon must be neutral grayscale');
        for (const p of [0, width - 1, (height - 1) * width, height * width - 1]) assert.equal(data[p * 3], 0, 'Tinted icon corners must be black');
      }
      if (file.endsWith('.svg')) assert(!(await fs.readFile(target, 'utf8')).includes('<image'), 'SVG must contain vector paths');
      results.push({ file, width, height, alpha: info.hasAlpha, bytes: (await fs.stat(target)).size });
    }
  }
  await fs.writeFile(path.join(root, 'manifest.json'), JSON.stringify(results, null, 2) + '\n');
  console.log(`Validated ${results.length} exports`);
  return results;
}

async function gallery() {
  const files = [];
  for (const folder of ['emblem', 'logo', 'icon', 'keyart', 'banners', 'social']) for (const name of await fs.readdir(path.join(root, folder))) if (/\.(png|jpg|svg)$/.test(name)) files.push(`${folder}/${name}`);
  await fs.writeFile(path.join(root, 'index.html'), `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Quest for Duskara — Brand Assets</title><style>body{margin:0;padding:32px;background:#173A47;color:#F2E8D1;font:16px system-ui}h1{margin:0 0 24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,300px),1fr));gap:24px}figure{margin:0;background:#1B4A5E;padding:16px;border:1px solid #5F8F9C;border-radius:12px}img{display:block;width:100%;height:260px;object-fit:contain;background:repeating-conic-gradient(#2A5262 0% 25%,#244859 0% 50%) 50%/24px 24px}figcaption{margin-top:12px;overflow-wrap:anywhere}a{color:inherit}</style><h1>Quest for Duskara · Brand Assets</h1><p>${files.length} exports · <a href="prompts.json">Generation prompts</a> · <a href="manifest.json">Export manifest</a></p><p>Built from the latest supplied game screenshots. Steam assets await a Steam page; optional Icon Composer layers and Discord emoji are omitted.</p><main>${files.map(file => `<figure><a href="${file}"><img src="${file}" alt="${file.replace(/[-/]/g, ' ')}"></a><figcaption><a href="${file}">${file}</a></figcaption></figure>`).join('')}</main></html>\n`);
  console.log(`Gallery: ${files.length} assets`);
}

async function selfCheck() {
  const fixture = Buffer.from('<svg width="40" height="30"><rect x="5" y="5" width="30" height="20" fill="#F2E8D1"/><rect x="15" y="10" width="10" height="10" fill="#1B4A5E"/></svg>');
  const mark = await logo(fixture, 100, 60, true), svg = await vectorize(mark);
  const original = await sharp(mark).ensureAlpha().raw().toBuffer(), traced = await sharp(Buffer.from(svg)).ensureAlpha().raw().toBuffer();
  assert.equal(original.length, traced.length);
  let difference = 0;
  for (let i = 3; i < original.length; i += 4) difference += Math.abs(original[i] - traced[i]);
  assert(difference / (original.length / 4) < 8, 'Vector trace must preserve lettering and counters');
  const icon = await sharp(mark).resize(32, 32).toColourspace('srgb').flatten({ background: '#1B4A5E' }).removeAlpha().png(png).toBuffer();
  const info = await sharp(icon).metadata(); assert.equal(info.hasAlpha, false); assert.equal(info.channels, 3);
  console.log('Self-check passed: alpha, exact dimensions, solid-color trace, counters, opaque RGB icons.');
}

(async () => {
  if (process.argv[2] === '--self-check') return selfCheck();
  if (process.argv[2] === 'gallery') return gallery();
  if (process.argv[2] === 'validate') return validate(process.argv[3]);
  if (process.argv[2] === 'run') {
    for (const job of JSON.parse(await fs.readFile(process.argv[3], 'utf8'))) console.log(JSON.stringify(await exportJob(job)));
    await validate(process.argv[3]); return gallery();
  }
  if (process.argv[2] === 'export') { console.log(JSON.stringify(await exportJob(JSON.parse(process.argv[3])))); return; }
  console.log('Usage: node brand-assets/export.cjs --self-check | run plan.json | validate plan.json | export \'{"kind":"icon","input":".sources/icon-default.png","output":"icon/icon-default.png","width":1024,"height":1024}\' | gallery');
})().catch(error => { console.error(error); process.exitCode = 1; });
