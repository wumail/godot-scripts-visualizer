#!/usr/bin/env node

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'esbuild';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..', '..');
const srcDir = join(projectRoot, 'web', 'src', 'visualizer');
const outputDir = join(projectRoot, 'addons', 'godot_visualizer_native', 'web');

export async function buildVisualizer() {
  mkdirSync(outputDir, { recursive: true });

  const template = readFileSync(join(srcDir, 'template.html'), 'utf-8');
  const css = readFileSync(join(srcDir, 'visualizer.css'), 'utf-8');

  const jsResult = await build({
    entryPoints: [join(srcDir, 'main.js')],
    bundle: true,
    format: 'iife',
    minify: false,
    write: false,
    target: ['es2020'],
    sourcemap: false,
  });

  const bundledJs = jsResult.outputFiles[0].text;
  // Use function replacers so `$` sequences in the CSS/JS (e.g. `$&`, `$$`) are
  // inserted literally instead of being treated as replacement patterns.
  const html = template
    .replace('%%CSS%%', () => css)
    .replace('%%SCRIPT%%', () => bundledJs);

  const outputPath = join(outputDir, 'visualizer.html');
  writeFileSync(outputPath, html, 'utf-8');

  return outputPath;
}

const isDirectRun = process.argv[1] === fileURLToPath(import.meta.url);

if (isDirectRun) {
  buildVisualizer()
    .then((outputPath) => {
      console.log(`Built visualizer to ${outputPath}`);
    })
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}