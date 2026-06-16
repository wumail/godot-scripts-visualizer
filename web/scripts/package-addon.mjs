#!/usr/bin/env node

import { createWriteStream } from 'node:fs';
import { mkdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import archiver from 'archiver';

import { buildVisualizer } from './build-visualizer.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..', '..');
const addonDir = join(projectRoot, 'addons', 'godot_visualizer_native');
const distDir = join(projectRoot, 'dist');
const packageJsonPath = join(projectRoot, 'web', 'package.json');

async function packageAddon() {
  const packageJson = JSON.parse(await readFile(packageJsonPath, 'utf-8'));
  const version = packageJson.version ?? '0.1.0';
  const outputPath = join(distDir, `godot_visualizer_native-${version}.zip`);

  await buildVisualizer();
  await mkdir(distDir, { recursive: true });

  await new Promise((resolve, reject) => {
    const output = createWriteStream(outputPath);
    const archive = archiver('zip', { zlib: { level: 9 } });

    output.on('close', resolve);
    output.on('error', reject);
    archive.on('error', reject);

    archive.pipe(output);
    archive.directory(addonDir, 'addons/godot_visualizer_native');
    archive.finalize();
  });

  return outputPath;
}

packageAddon()
  .then((outputPath) => {
    console.log(`Packaged addon to ${outputPath}`);
  })
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });