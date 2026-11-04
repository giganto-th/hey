import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const directory = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(resolve(directory, 'preview.fragment.html'), 'utf8');
const image = readFileSync(resolve(directory, 'heihei-motion-preview-v1.webp')).toString('base64');
const fragment = source.replace('__SHEET__', `url('data:image/webp;base64,${image}')`);
if (fragment.includes('__SHEET__')) throw new Error('Unresolved image placeholder');
for (const match of fragment.matchAll(/<script>([\s\S]*?)<\/script>/g)) new Function(match[1]);
if (Buffer.byteLength(fragment) >= 1_000_000) throw new Error('Inline preview exceeds 1 MB');

const standalone = `<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><title>Hey! — Hei Hei UX concept</title>
<style>body{margin:0;padding:24px;background:light-dark(#fbfaf7,#191c1a);color-scheme:light dark}main{max-width:1080px;margin:auto}@media(max-width:560px){body{padding:12px}}</style></head><body><main>${fragment}</main></body></html>`;
const output = resolve(directory, 'preview.html');
writeFileSync(output, standalone);
if (process.argv[2]) writeFileSync(resolve(process.argv[2]), fragment);
console.log(`Preview: ${output}\nFragment: ${Buffer.byteLength(fragment)} bytes\nJavaScript syntax: passed`);
