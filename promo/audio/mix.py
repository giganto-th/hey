import numpy as np, wave, subprocess, os
SR = 44100
DUR = 48.2
OLD=[0,.8,3.1,6.9,12.7,18.3,25.2,30,34,39]; NEW=[0,.8,3.7,8.06,15.94,23.0,32.64,39.5,44.2,48.2]
def W(t): return float(np.interp(t,OLD,NEW))
here = os.path.dirname(os.path.abspath(__file__))
vd = os.path.join(here, '..', 'voice11')
N = int(SR * DUR)
music = np.zeros(N); sfx = np.zeros(N); voice = np.zeros(N)

def add(buf, x, at, g=1.0, raw=False):
    if buf is sfx and not raw: at = W(at)
    i = int(at * SR)
    if i >= len(buf): return
    x = x[:len(buf) - i]
    buf[i:i + len(x)] += x * g

def env(n, a, d):
    t = np.arange(n) / SR
    return np.minimum(t / a, 1) * np.exp(-t / d)

def tone(f, dur, a=.01, d=.3, harm=(1, .3, .1)):
    n = int(dur * SR); t = np.arange(n) / SR
    y = sum(h * np.sin(2 * np.pi * f * (k + 1) * t) for k, h in enumerate(harm))
    return y * env(n, a, d)

def mid(m): return 440 * 2 ** ((m - 69) / 12)

os.makedirs('/tmp/promo', exist_ok=True)
starts = {'v1': .8, 'v2': 3.7, 'v3': 8.06, 'v4': 15.94, 'v5': 23.0, 'v6': 32.64, 'v7': 39.5, 'v8': 44.2}
for k, t0 in starts.items():
    w = os.path.join(vd, 'f' + k[1:] + '.wav'); o = '/tmp/promo/' + k + '_44.wav'
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', w, '-ac', '1', '-ar', str(SR), '-sample_fmt', 's16', o], check=True)
    with wave.open(o) as f:
        x = np.frombuffer(f.readframes(f.getnframes()), dtype=np.int16) / 32768
    add(voice, x, t0, 1.0)

bar = 2.4
chords = [[48, 55, 60, 64], [45, 52, 57, 60], [41, 48, 53, 57], [43, 50, 55, 59]]
for b in range(int(DUR / bar) + 1):
    ch = chords[b % 4]; t0 = b * bar
    for m in ch[:3]:
        add(music, tone(mid(m), bar + .8, a=.5, d=2.5, harm=(1, .15)), t0, .07)
    arp = [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[2] + 12, ch[1] + 12, ch[3] + 12, ch[2] + 12]
    for i, m in enumerate(arp):
        add(music, tone(mid(m), .9, a=.004, d=.22, harm=(1, .4, .12)), t0 + i * bar / 8, .10 if i % 2 == 0 else .065)
    add(music, tone(mid(ch[0] - 12), bar, a=.02, d=.9, harm=(1, .5)), t0, .16)

def pop(f=520):
    n = int(.18 * SR); t = np.arange(n) / SR
    fr = f * (1 + 1.5 * np.exp(-t * 30))
    return np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t * 22)

def tick():
    n = int(.04 * SR); r = np.random.RandomState(1).randn(n)
    return r * np.exp(-np.arange(n) / SR * 180) * .5

def sparkle():
    y = np.zeros(int(.9 * SR))
    for i, m in enumerate([84, 88, 91, 96]):
        add(y, tone(mid(m), .5, a=.002, d=.15), i * .06, .5)
    return y

def whoosh():
    n = int(.7 * SR); r = np.random.RandomState(2).randn(n)
    k = np.convolve(r, np.ones(60) / 60, mode='same'); t = np.arange(n) / SR
    return k * np.sin(np.pi * np.clip(t / .7, 0, 1)) ** 2 * 2

for t in (1.1, 1.6, 2.0, 2.35): add(sfx, tick(), t, .6)
add(sfx, sparkle(), 2.65, .35); add(sfx, pop(), 3.5, .3)
add(sfx, whoosh(), 6.3, .3); add(sfx, pop(420), 6.8, .35)
add(sfx, pop(700), 9.4, .3); add(sfx, sparkle(), 11.2, .3)
add(sfx, whoosh(), 12.4, .3)
for t in (12.9, 14.0, 15.2, 16.4): add(sfx, pop(600), t, .22)
add(sfx, whoosh(), 18.0, .25)
for i, t in enumerate((19.2, 20.5, 22.1, 22.9, 23.6, 24.1)): add(sfx, pop(480 + (i % 5) * 40), t, .3)
add(sfx, whoosh(), 24.7, .25)
for i, t in enumerate((25.6, 26.4, 27.2, 28.0, 28.8)): add(sfx, pop(400 + i * 70), t, .3)
add(sfx, sparkle(), 29.0, .35)
add(sfx, whoosh(), 29.6, .25)
for t in (30.3, 31.2, 32.1): add(sfx, pop(560), t, .3)
add(sfx, whoosh(), 33.6, .3); add(sfx, sparkle(), 34.2, .4)

k = int(.15 * SR)
venv = np.clip(np.convolve(np.abs(voice), np.ones(k) / k, mode='same') * 12, 0, 1)
mix = music * (1 - .55 * venv) + sfx * .9 + voice
fi = np.minimum(np.arange(N) / (SR * .8), 1); fo = np.minimum((N - np.arange(N)) / (SR * 1.8), 1)
mix *= fi * fo
mix /= max(1e-6, np.max(np.abs(mix))) / 0.9
with wave.open(os.path.join(here, 'mix.wav'), 'wb') as f:
    f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR)
    f.writeframes((mix * 32767).astype(np.int16).tobytes())
print('ok')
