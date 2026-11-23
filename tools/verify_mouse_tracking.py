"""Real X11 pointer regression: window edges, pauses, upgrades and focus return.

Runs on a private Xvfb display; never moves the pointer on the user's desktop.
Use --executable PATH to check a packaged build instead of the project.
Requires Pillow, Xvfb, xwininfo and libXtst in the verification environment.
"""
from pathlib import Path
import argparse,ctypes,json,math,os,re,select,subprocess,tempfile,time
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--executable',type=Path)
parser.add_argument('--report',default='mouse_tracking')
args=parser.parse_args()
output=ROOT/'build/verification';output.mkdir(exist_ok=True,parents=True)
observations=[];checks=[]

def check(ok,label):
    checks.append({'check':label,'passed':bool(ok)})
    print(('PASS ' if ok else 'FAIL ')+label,flush=True)

with tempfile.TemporaryDirectory(prefix='lastcall-mouse-') as temporary:
    directory=Path(temporary)
    read_fd,write_fd=os.pipe()
    xvfb=subprocess.Popen(['Xvfb','-displayfd',str(write_fd),'-screen','0','1920x1080x24','-nolisten','tcp'],pass_fds=(write_fd,),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    os.close(write_fd)
    process=None
    try:
        assert select.select([read_fd],[],[],10)[0],'Xvfb startup timeout'
        display=':'+os.read(read_fd,64).decode().strip();os.close(read_fd)
        env={**os.environ,'DISPLAY':display,'LASTCALL_MOUSE_TEST_DIR':str(directory)}
        executable=args.executable or Path.home()/'.cache/codex-tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64'
        command=[str(executable.resolve())]
        if not args.executable:command+=['--path',str(ROOT/'game')]
        command+=['--windowed','--resolution','960x540','--position','200,150','--','--mouse-test']
        log=(output/(args.report+'.log')).open('w')
        process=subprocess.Popen(command,cwd='/tmp',env=env,stdout=log,stderr=subprocess.STDOUT)
        def wait_file(path,timeout=30):
            end=time.monotonic()+timeout
            while not path.exists():
                assert process.poll() is None,'Game exited: '+str(output/(args.report+'.log'))
                assert time.monotonic()<end,'Timed out waiting for '+path.name
                time.sleep(.03)
            return json.loads(path.read_text())
        ready=wait_file(directory/'ready.json')
        X=ctypes.CDLL('libX11.so.6');T=ctypes.CDLL('libXtst.so.6')
        X.XOpenDisplay.argtypes=[ctypes.c_char_p];X.XOpenDisplay.restype=ctypes.c_void_p
        X.XDefaultRootWindow.argtypes=[ctypes.c_void_p];X.XDefaultRootWindow.restype=ctypes.c_ulong
        X.XFlush.argtypes=[ctypes.c_void_p]
        X.XSetInputFocus.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_ulong]
        X.XRaiseWindow.argtypes=[ctypes.c_void_p,ctypes.c_ulong]
        X.XQueryPointer.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_int),ctypes.POINTER(ctypes.c_uint)]
        X.XQueryPointer.restype=ctypes.c_int
        T.XTestFakeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
        T.XTestFakeRelativeMotionEvent.argtypes=[ctypes.c_void_p,ctypes.c_int,ctypes.c_int,ctypes.c_ulong]
        T.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
        T.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p,ctypes.c_uint,ctypes.c_int,ctypes.c_ulong]
        X.XKeysymToKeycode.argtypes=[ctypes.c_void_p,ctypes.c_ulong];X.XKeysymToKeycode.restype=ctypes.c_uint
        d=X.XOpenDisplay(display.encode());root=X.XDefaultRootWindow(d)
        tree=subprocess.check_output(['xwininfo','-root','-tree'],env=env,text=True)
        match=re.search(r'(0x[0-9a-f]+) "Mustache Massacre',tree);assert match,'Game window missing'
        window=int(match.group(1),16)
        X.XRaiseWindow(d,window);X.XSetInputFocus(d,window,2,0);X.XFlush(d)
        x,y=ready['window_position'];w,h=ready['window_size']
        def move(px,py):
            T.XTestFakeMotionEvent(d,-1,int(px),int(py),0);X.XFlush(d);time.sleep(.12)
        def key(symbol,pressed):
            T.XTestFakeKeyEvent(d,X.XKeysymToKeycode(d,symbol),pressed,0);X.XFlush(d);time.sleep(.08)
        def button(pressed):
            T.XTestFakeButtonEvent(d,1,pressed,0);X.XFlush(d);time.sleep(.08)
        def pointer():
            rr=ctypes.c_ulong();cr=ctypes.c_ulong();rx=ctypes.c_int();ry=ctypes.c_int();wx=ctypes.c_int();wy=ctypes.c_int();mask=ctypes.c_uint()
            X.XQueryPointer(d,root,ctypes.byref(rr),ctypes.byref(cr),ctypes.byref(rx),ctypes.byref(ry),ctypes.byref(wx),ctypes.byref(wy),ctypes.byref(mask))
            return rx.value,ry.value
        def sample(label,action='sample'):
            command={'id':label,'action':action}
            temp=directory/'command.tmp';temp.write_text(json.dumps(command));temp.replace(directory/'command.json')
            state=wait_file(directory/(label+'.json'))
            state['label']=label;state['physical_pointer']=pointer();observations.append(state)
            return state
        def tracking(label,px,py):
            move(px,py);state=sample(label)
            rx,ry=state['physical_pointer'];vw,vh=state['viewport_size']
            expected=[(rx-x)*vw/w,(ry-y)*vh/h]
            check(math.dist(state['mouse'],expected)<2,label+': viewport tracks physical cursor')
            check(math.dist(state['aim_screen'],expected)<2,label+': gun aim tracks cursor')
            # Confirm the crosshair was actually painted at that position.
            image=Image.open(directory/(label+'.png')).convert('RGB')
            cx=round(state['mouse'][0]*image.width/vw);cy=round(state['mouse'][1]*image.height/vh)
            pixels=[image.getpixel((ix,iy)) for ix in range(max(0,cx-1),min(image.width,cx+2)) for iy in range(max(0,cy-1),min(image.height,cy+2))]
            check(any(r>225 and g>200 and b>155 for r,g,b in pixels),label+': visible crosshair follows cursor')
            return state
        move(x+w*.4,y+h*.55)
        check(sample('arrival')['mouse_mode']==0,'arrival releases the visible cursor')
        sample('start','start')
        tracking('initial',x+w*.4,y+h*.55)
        # Cross the round banner using relative pointer motion while holding fire
        # and movement, then resume through the actual pause-menu button.
        sample('round_banner','wave')
        banner=tracking('banner_hover',x+w*.5,y+h*190/1080)
        check(banner['toast_timer']>0,'round banner visible during hover')
        key(ord('w'),True);button(True)
        for step in range(4):
            T.XTestFakeRelativeMotionEvent(d,35,4,0);X.XFlush(d);time.sleep(.15)
        rx,ry=pointer()
        moved=tracking('banner_held_fire',rx,ry)
        check(moved['shots']>banner['shots'],'firing continues over round banner')
        button(False);key(ord('w'),False)
        key(0xff1b,True);key(0xff1b,False)
        paused=sample('banner_escape_pause')
        check(paused['panel']=='pause' and paused['paused'],'Escape opens pause after banner hover')
        resume=next(b for b in paused['buttons'] if b['text']=='BACK TO THE BADLANDS')
        vw,vh=paused['viewport_size'];bx,by=resume['center']
        move(x+bx*w/vw,y+by*h/vh);button(True);button(False)
        resumed=tracking('banner_button_resume',x+w*.5,y+h*190/1080)
        check(not resumed['paused'] and resumed['panel']=='','pause button resumes after banner hover')
        time.sleep(3)
        expired=tracking('banner_expired',x+w*.6,y+h*.3)
        check(expired['toast_timer']==0,'tracking continues after round banner expires')
        for label,px,py in [('right',x+w+180,y+h*.55),('left',x-180,y+h*.55),('bottom',x+w*.4,y+h+180),('top',x+w*.4,y-120)]:
            move(px,py);state=sample('edge_'+label);rx,ry=state['physical_pointer']
            check(x<=rx<x+w and y<=ry<y+h,label+' edge keeps cursor inside combat window')
            tracking('return_'+label,x+w*.35,y+h*.65)
        check(sample('pause','pause')['mouse_mode']==0,'pause releases the visible cursor')
        move(x+w+100,y+h*.55);rx,ry=pointer();check(rx>=x+w,'pause permits pointer to leave the window')
        sample('resume','resume');tracking('after_pause',x+w*.6,y+h*.5)
        move(x+w+100,y+h*.5);rx,ry=pointer();check(rx<x+w,'resume restores confinement')
        check(sample('upgrade','upgrade')['mouse_mode']==0,'upgrade choice releases cursor')
        sample('choose','choose');tracking('after_upgrade',x+w*.3,y+h*.6)
        move(x+w+100,y+h*.5);rx,ry=pointer();check(rx<x+w,'upgrade selection restores confinement')
        X.XSetInputFocus(d,root,2,0);X.XFlush(d);time.sleep(.2)
        X.XSetInputFocus(d,window,2,0);X.XFlush(d);time.sleep(.2)
        tracking('after_focus_return',x+w*.65,y+h*.7)
        move(x+w+100,y+h*.5);rx,ry=pointer();check(rx<x+w,'focus return restores confinement')
        check(sample('results','results')['mouse_mode']==0,'results release visible cursor')
        temp=directory/'command.tmp';temp.write_text(json.dumps({'id':'quit','action':'quit'}));temp.replace(directory/'command.json')
        process.wait(timeout=10);log.close()
        report={'passed':sum(c['passed'] for c in checks),'failed':sum(not c['passed'] for c in checks),'checks':checks,'observations':observations}
        (output/(args.report+'.json')).write_text(json.dumps(report,indent=2))
        assert report['failed']==0,f"{report['failed']} mouse checks failed"
    finally:
        if process and process.poll() is None:process.terminate();process.wait(timeout=10)
        xvfb.terminate();xvfb.wait(timeout=10)
