// Exercises the real embedded player commands without YouTube or network access.
// Run: node scripts/test-youtube-quality.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';

const source = readFileSync(new URL('../Sources/Hey/MusicPlayer.swift', import.meta.url), 'utf8');
const html = source.match(/private static let htmlTemplate = """([\s\S]*?)"""/)[1];
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const qualityCalls = [];
const loads = [];
let events;
const player = {
  setPlaybackQualityRange: (...args) => qualityCalls.push(args),
  setPlaybackQuality: (...args) => qualityCalls.push(args),
  loadVideoById: request => loads.push(request),
};
const context = vm.createContext({
  ORIGIN: 'https://test.invalid',
  window: { webkit: { messageHandlers: { hey: { postMessage() {} } } } },
  document: { createElement: () => ({}), head: { appendChild() {} } },
  setInterval() {},
  YT: { Player: function (_, options) { events = options.events; return player; } },
});
vm.runInContext(script, context);
vm.runInContext("onYouTubeIframeAPIReady(); heyLoad('M7lc1UVf-VE')", context);
events.onReady();
events.onStateChange({ data: 3 });
events.onStateChange({ data: 1 });
assert.equal(loads.length, 1, 'queued video should load once the player is ready');
assert.notEqual(loads[0].suggestedQuality, 'tiny', 'do not request minimum-quality video');
assert.equal(qualityCalls.length, 0, 'do not override YouTube adaptive quality');
assert.ok(!source.includes('config.userContentController.addUserScript(lowest)'),
  'do not inject a script that forces minimum quality inside the iframe');
console.log('PASS: video loads without forcing minimum quality');
