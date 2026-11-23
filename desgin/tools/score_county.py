"""Render original 8-bar location loops. The shared pulse keeps road transitions short."""
from pathlib import Path
import wave
import numpy as np
OUT=Path(__file__).resolve().parents[2]/'game/assets/county'
rate=22050
for name,beat,notes in [('grease',.18,[40,47,50,52,55,52,47,43]),
                        ('funland',.205,[74,77,81,79,76,74,70,73]),
                        ('palace',.29,[50,57,62,65,64,60,55,57])]:
    length=64*beat
    sample=np.zeros(round(rate*length))
    for idx in range(64):
        if name=='palace' and idx%2:continue
        note=notes[(idx//2+3*(idx//16))%8]-(12 if idx%8==0 else 0)
        if name=='funland' and idx%3==2:note-=12
        freq=440*2**((note-69)/12)
        duration=beat*(2.7 if name=='palace' else 1.42)
        t=np.arange(round(rate*duration))/rate
        voice=np.zeros(len(t))
        for harmonic,amplitude in ([(1,.6),(2,.22),(3,.12),(5,.05)] if name!='grease' else [(1,.75),(3,.22),(7,.09)]):
            voice+=amplitude*np.sin(2*np.pi*freq*harmonic*t+.016*np.sin(2*np.pi*5*t))
        env=(1-np.exp(-t/(.06 if name=='palace' else .008)))*np.exp(-t/(duration*.38))
        env*=np.minimum(1,(duration-t)/.035)
        indices=(round(idx*beat*rate)+np.arange(len(t)))%len(sample)
        sample[indices]+=voice*env
    with wave.open(str(OUT/(name+'.wav')),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes((sample*(9200/np.max(np.abs(sample)))).astype('<i2').tobytes())
