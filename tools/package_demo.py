"""Package the tested Linux release and the reproducible source checkout."""
from pathlib import Path
import hashlib,zipfile,shutil
ROOT=Path(__file__).resolve().parents[1]
RELEASES=ROOT/'build/releases'
PACKAGE=RELEASES/'LastCall'

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

files=sorted(p for p in PACKAGE.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt')
(PACKAGE/'SHA256SUMS.txt').write_text(''.join(digest(p)+'  '+p.relative_to(PACKAGE).as_posix()+'\n' for p in files))
binary=RELEASES/'MustacheMassacre-LastCall-linux-x86_64.zip'
with zipfile.ZipFile(binary.with_suffix('.zip.new'),'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in sorted(PACKAGE.rglob('*')):
        if p.is_file():archive.write(p,'LastCall/'+p.relative_to(PACKAGE).as_posix())

binary.with_suffix('.zip.new').replace(binary)

source=RELEASES/'MustacheMassacre-LastCall-source.zip'
source_files=[]
for folder in ['game','tools','desgin/docs','desgin/tools','desgin/agents','.agents/skills/character-artist','.agents/skills/environment-artist','desgin/prop_models/badlands','desgin/renders/badlands_props','desgin/renders/grooming_garage','desgin/renders/badlands_expansion','desgin/prop_models/grease_city','desgin/renders/grease_city','desgin/renders/general_coo','desgin/prop_models/county','desgin/renders/county','desgin/renders/grand_palace/concepts']:
    source_files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and '.godot' not in p.parts and '__pycache__' not in p.parts and p.suffix != '.blend1')
source_files.extend(PACKAGE/name for name in ['play.sh','play-natural.sh','launch_godot.sh','README.md'])
source_files.extend(path for path in (PACKAGE/'licenses').glob('*') if path.is_file())
for name in ['README.md','AGENTS.md','.gitignore','requirements-art.txt','desgin/character_models/DON_ESPINO_hero_v3.blend','desgin/character_models/DON_ESPINO.fbx','desgin/renders/don_espino/v3/README.md','desgin/renders/don_espino/v3/01_actual_blender_hero.png','desgin/renders/don_espino/concepts/01_character_hero.png']:
    source_files.append(ROOT/name)
for name in ['README.md','county.json','badlands_expansion.json','badlands_expansion_mouse.json','grease_city.json','grease_city_mouse.json','badlands_environment.json','badlands_environment_mouse.json','badlands_enemies.json','asset_integrity.json','combat_tests.json','performance.json','input_audit.json','rendered_playthrough.json','frozen_release.json','playthrough_build.json','archive_verification.json','exported_combat.log','exported_restarts.log','rendered_playthrough.log','exported_stress.log','exported_input.log','checksums.log']:
    source_files.append(ROOT/'build/verification'/name)
for name in ['mouse_tracking_before.json','mouse_tracking_fixed.json','mouse_tracking_exported.json']:
    source_files.append(ROOT/'build/verification'/name)
source_files.extend((ROOT/'build/verification/screenshots').rglob('*.png'))
natural=ROOT/'desgin/character_models/refined/don_espino_natural_workflow'
source_files.append(ROOT/'desgin/character_models/refined/DonEspinoNatural.glb')
source_files.extend(natural/name for name in ['README.md','DonEspinoNatural_candidate.blend','audit.json','animation_manifest.json','mixamo_clips.json','mixamo_directions.json','retarget_validation.json','export_validation.json'])
source_files.extend((ROOT/'build/natural_character_workflow'/name) for name in ['gameplay_validation.json','performance.json','performance_default_same_display.json','godot_review.log','arena_visual.log'])
source_files.extend((ROOT/'desgin/renders/don_espino/natural_workflow').glob('*.png'))
source_files.extend((ROOT/'desgin/renders/don_espino/refined_workflow'/name) for name in ['07_neutral_pose_generation_reference.png','neutral_reference_prompt.md'])
source_files.append(ROOT/'desgin/character_models/refined/don_espino_workflow/README.md')
source_files.append(natural/'03_moustache_and_revolver.blend')
for enemy in ['fridge_bruiser','chili_bandit','pigeon_bomber','el_frigorifico','skillet_outlaw','repair_appliance','general_coo','mustard','puppet','brush','dodgem','flushness']:
    for folder in [ROOT/'desgin/character_models/generated'/enemy,ROOT/'desgin/renders'/enemy/'concepts']:
        source_files.extend(path for path in folder.rglob('*') if path.is_file() and path.suffix != '.blend1')
source_files.extend(path for path in (ROOT/'desgin/renders/badlands_enemies').rglob('*') if path.is_file())
source_files.extend((ROOT/'desgin/renders/don_espino/high_noon').glob('*.*'))
source_files.append(ROOT/'build/verification/high_noon.json')
source_files.extend((ROOT/'desgin/renders/don_espino/saguaro_lance').glob('*.*'))
source_files.append(ROOT/'build/verification/saguaro_lance.json')
source_files.append(ROOT/'desgin/renders/don_espino/specials_autoplay/opening.mp4')
with zipfile.ZipFile(source.with_suffix('.zip.new'),'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for p in sorted(set(source_files)):
        if p.exists():archive.write(p,'MustacheMassacre/'+p.relative_to(ROOT).as_posix())
source.with_suffix('.zip.new').replace(source)
(RELEASES/'SHA256SUMS.txt').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in [binary,source,RELEASES/'MoustacheMassacre-x86_64.AppImage'] if p.is_file()))
for p in [binary,source]:print(p.relative_to(ROOT),round(p.stat().st_size/1024/1024,1),'MiB',flush=True)
