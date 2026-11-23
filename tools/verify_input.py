"""Launch the exported demo and exercise real X11 keyboard/mouse input."""
from pathlib import Path
import ctypes,json,subprocess,time,re,os
root=Path(__file__).resolve().parents[1]
userdata=Path.home()/'.local/share/godot/app_userdata/Mustache Massacre — Last Call'
target_file=userdata/'input_target.json'
log=(root/'build/verification/exported_input.log').open('w')
started=time.time()
process=subprocess.Popen([str(root/'build/releases/LastCall/LastCall.x86_64'),'--fullscreen','--resolution','1920x1080','--','--input-audit'],cwd='/tmp',env={**os.environ,'DISPLAY':':1'},stdout=log,stderr=subprocess.STDOUT)
while not target_file.exists() or target_file.stat().st_mtime<started:
    if process.poll() is not None or time.time()-started>30:raise RuntimeError('Demo did not become ready')
    time.sleep(.1)
X=ctypes.CDLL('libX11.so.6');T=ctypes.CDLL('libXtst.so.6')
X.XOpenDisplay.argtypes=[ctypes.c_char_p];X.XOpenDisplay.restype=ctypes.c_void_p
X.XStringToKeysym.argtypes=[ctypes.c_char_p];X.XStringToKeysym.restype=ctypes.c_ulong
X.XKeysymToKeycode.argtypes=[ctypes.c_void_p,ctypes.c_ulong];X.XKeysymToKeycode.restype=ctypes.c_uint
X.XFlush.argtypes=[ctypes.c_void_p]
X.XRaiseWindow.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
X.XSetInputFocus.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_ulong]
T.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
T.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
T.XTestFakeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
d=X.XOpenDisplay(b':1')
windows=subprocess.check_output(['xwininfo','-root','-tree'],env={**os.environ,'DISPLAY':':1'},text=True)
match=re.search(r'(0x[0-9a-f]+) "Mustache Massacre',windows)
if not match:raise RuntimeError('Demo window missing')
window=int(match.group(1),16);X.XRaiseWindow(d,window);X.XSetInputFocus(d,window,2,0);X.XFlush(d)
def key(name,seconds=.08):
    c=X.XKeysymToKeycode(d,X.XStringToKeysym(name.encode()))
    T.XTestFakeKeyEvent(d,c,1,0);X.XFlush(d);time.sleep(seconds)
    T.XTestFakeKeyEvent(d,c,0,0);X.XFlush(d)
def fire(seconds):
    T.XTestFakeButtonEvent(d,1,1,0);X.XFlush(d);time.sleep(seconds)
    T.XTestFakeButtonEvent(d,1,0,0);X.XFlush(d)
target=json.loads(target_file.read_text())
T.XTestFakeMotionEvent(d,-1,int(target['x']),int(target['y']),0);X.XFlush(d)
fire(1.5);key('r');time.sleep(.64);key('r');key('Return');time.sleep(.5)
key('w',.8);key('d',.6);key('space');key('q');key('e');key('f');key('s',.7);key('a',.7)
key('Escape');time.sleep(1);key('Escape');time.sleep(.5);fire(1)
process.wait(timeout=30);log.close()
report=json.loads((userdata/'input_audit.json').read_text())
required=['move_left','move_right','move_forward','move_back','fire','reload','dash','ricochet','tumbleweed','ultimate','pause','start_run']
assert all(report['events'].get(key,0)>0 for key in required),report
assert report['movement_metres']>2 and report['saw_pause'] and report['shots']>=6 and report['wave']==1,report
print(json.dumps(report,indent=2))
