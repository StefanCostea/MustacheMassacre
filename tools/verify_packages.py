"""Check both archives after extraction, including a cold Godot source import."""
from pathlib import Path
import tempfile,zipfile,subprocess,hashlib,json,os

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification'
RELEASES=ROOT/'build/releases'
ENGINE=Path(os.environ.get('GODOT_BIN',str(Path.home()/'.cache/codex-tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64')))

def run(command,filename,timeout=180):
    path=OUT/filename
    with path.open('w') as log:
        result=subprocess.run([str(x) for x in command],cwd='/tmp',stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
    contents=path.read_text()
    assert result.returncode==0,(filename,result.returncode)
    assert 'ERROR' not in contents and 'Assertion' not in contents,filename
    return contents

def check_combat(text):
    line=next(x for x in text.splitlines() if x.startswith('COMBAT_TESTS '))
    result=json.loads(line.removeprefix('COMBAT_TESTS '))
    assert result['passed']==53 and result['failed']==0

def check_enemy_motion(text):
    line = next(line for line in text.splitlines() if line.startswith('ENEMY_ANIMATION_TEST '))
    fields = dict(field.split('=') for field in line.split()[1:])
    assert int(fields['checks']) > 0 and fields['failures'] == '0', line
    return int(fields['checks'])

def check_environment(contents):
    line = next(line for line in contents.splitlines() if line.startswith('ENVIRONMENT_TEST '))
    values = dict(field.split('=') for field in line.split()[1:])
    assert int(values['checks']) >= 31 and values['failures'] == '0', line
    return int(values['checks'])

def special_checks(command, kind, flag_name, minimum):
    result = {}
    for hero, hero_flags in [('original', []), ('natural', ['--natural-hero']), ('motion_study', ['--espino-motion-study'])]:
        log = run([*command, '--headless', '--fixed-fps', '60', '--', '--'+flag_name.replace('_','-'), *hero_flags],
                  f'{kind}_{flag_name}_{hero}.log')
        line = next(line for line in log.splitlines() if line.startswith(flag_name.upper()+' '))
        fields = dict(field.split('=') for field in line.split()[1:])
        assert int(fields['checks']) >= minimum and fields['failures'] == '0', line
        result[hero] = int(fields['checks'])
    return result

def check_specials_autoplay(command, kind):
    log = run([*command, '--headless', '--fixed-fps', '60', '--', '--autoplay-specials', '--natural-hero'],
              f'{kind}_specials_autoplay.log')
    opening = json.loads(next(line.removeprefix('SPECIALS_OPENING ') for line in log.splitlines()
                              if line.startswith('SPECIALS_OPENING ')))
    assert opening['seconds'] < 15 and min(opening['high_noon_kills'], opening['saguaro_lance_kills']) > 0, opening
    report = json.loads(next(line.removeprefix('AUTOPLAY_REPORT ') for line in log.splitlines()
                             if line.startswith('AUTOPLAY_REPORT ')))
    counts = report['actions']['special_casts']
    assert report['won'] and counts['saguaro_lance'] >= 2 and counts['high_noon'] - counts['saguaro_lance'] in (0, 1)
    assert sum(counts.values()) == report['actions']['ultimates']
    return {'opening': opening, 'casts': counts, 'seconds': report['seconds'], 'won': report['won']}

def campaign_checks(command, kind):
    checks = {}
    for branch in ('freight', 'fry_line'):
        log = run([*command, '--headless', '--fixed-fps', '60', '--', '--natural-hero',
                   '--campaign-test', '--route-' + branch.replace('_', '-')], f'{kind}_campaign_{branch}.log')
        line = next(line for line in log.splitlines() if line.startswith('CAMPAIGN_TEST '))
        fields = dict(field.split('=') for field in line.split()[1:])
        assert fields['branch'] == branch and fields['failures'] == '0' and int(fields['checks']) >= 35, line
        checks[branch] = int(fields['checks'])
    log = run([*command, '--headless', '--fixed-fps', '60', '--', '--paired-ui-test'], f'{kind}_paired_ui.log')
    assert 'failures=0 runs=2' in log
    checks['paired_ui_runs'] = 2
    return checks

results={}
with tempfile.TemporaryDirectory(prefix='lastcall-verify-') as temporary:
    temporary=Path(temporary)
    os.environ['XDG_DATA_HOME']=str(temporary/'profile')
    for kind,name in [('binary','MustacheMassacre-LastCall-linux-x86_64.zip'),('source','MustacheMassacre-LastCall-source.zip')]:
        with zipfile.ZipFile(RELEASES/name) as archive:
            assert archive.testzip() is None
            archive.extractall(temporary)
            for info in archive.infolist():
                target=temporary/info.filename
                if target.is_file():target.chmod((info.external_attr>>16)&0o777 or 0o644)
        print('ZIP CRC PASS',kind,flush=True)
    binary=temporary/'LastCall'
    for line in (binary/'SHA256SUMS.txt').read_text().splitlines():
        expected,name=line.split('  ',1)
        assert hashlib.sha256((binary/name).read_bytes()).hexdigest()==expected
    check_combat(run([binary/'play.sh','--headless','--fixed-fps','60','--','--test'],'extracted_combat.log'))
    if (binary/'play-natural.sh').exists():
        check_combat(run([binary/'play-natural.sh','--headless','--fixed-fps','60','--','--test'],'extracted_natural.log'))
    results['binary']='CRC, embedded hashes, executable permissions and 53 gameplay checks in both hero modes passed after extraction'
    results['binary_enemy_animation_checks']=check_enemy_motion(run([binary/'play.sh','--headless','--fixed-fps','60','--','--enemy-animation-test'],'extracted_enemy_motion.log'))
    results['binary_environment_checks']=check_environment(run([binary/'play-natural.sh','--headless','--fixed-fps','60','--','--environment-test'],'extracted_environment.log'))
    results['binary_high_noon_checks'] = special_checks([binary/'play.sh'], 'extracted', 'high_noon_test', 24)
    results['binary_loadout_checks'] = special_checks([binary/'play.sh'], 'extracted', 'loadout_test', 27)
    results['binary_expansion_checks'] = special_checks([binary/'play.sh'], 'extracted', 'badlands_expansion_test', 58)
    results['binary_specials_autoplay'] = check_specials_autoplay([binary/'play.sh'], 'extracted')
    results['binary_county_checks'] = special_checks([binary/'play.sh'], 'extracted', 'county_test', 40)
    results['binary_campaign'] = campaign_checks([binary/'play.sh'], 'extracted')
    source_root = temporary/'MustacheMassacre'
    environment = json.loads((source_root/'build/verification/badlands_environment.json').read_text())
    for kind, asset in environment['props'].items():
        glb = source_root/'game/assets/environment/props'/f'{kind}.glb'
        assert hashlib.sha256(glb.read_bytes()).hexdigest() == asset['sha256'], kind
        folder = source_root/'desgin/prop_models/badlands'/asset['source_revision']/kind
        result = json.loads((folder/'result.json').read_text())
        assert hashlib.sha256((folder/'source.glb').read_bytes()).hexdigest() == result['source_sha256'], kind
    assert (source_root/'.agents/skills/environment-artist/SKILL.md').is_file()
    release_hashes = json.loads((source_root/'build/verification/frozen_release.json').read_text())
    for relative, digest in release_hashes.items():
        assert hashlib.sha256((binary/Path(relative).name).read_bytes()).hexdigest() == digest
    game=temporary/'MustacheMassacre/game'
    run([ENGINE,'--headless','--path',game,'--editor','--import','--quit'],'source_import.log')
    check_combat(run([ENGINE,'--headless','--path',game,'--fixed-fps','60','--','--test'],'source_combat.log'))
    check_combat(run([ENGINE,'--headless','--path',game,'--fixed-fps','60','--','--test','--natural-hero'],'source_natural.log'))
    results['source']='CRC, fresh Godot import with no pre-existing .godot cache, and 53 gameplay checks in both hero modes passed'
    results['source_enemy_animation_checks']=check_enemy_motion(run([ENGINE,'--headless','--path',game,'--fixed-fps','60','--','--enemy-animation-test'],'source_enemy_motion.log'))
    results['source_environment_checks']=check_environment(run([ENGINE,'--headless','--path',game,'--fixed-fps','60','--','--environment-test','--natural-hero'],'source_environment.log'))
    results['source_high_noon_checks'] = special_checks([ENGINE, '--path', game], 'source', 'high_noon_test', 24)
    results['source_loadout_checks'] = special_checks([ENGINE, '--path', game], 'source', 'loadout_test', 27)
    results['source_expansion_checks'] = special_checks([ENGINE,'--path',game], 'source', 'badlands_expansion_test', 58)
    results['source_specials_autoplay'] = check_specials_autoplay([ENGINE, '--path', game], 'source')
    results['source_county_checks'] = special_checks([ENGINE,'--path',game], 'source', 'county_test', 40)
    results['source_campaign'] = campaign_checks([ENGINE,'--path',game], 'source')
    results['tested_game_hashes']={p.relative_to(game).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in game.rglob('*') if p.is_file() and '.godot' not in p.parts and p.suffix not in ['.import','.uid']}
(OUT/'archive_verification.json').write_text(json.dumps(results,indent=2))
print(results['binary'],flush=True)
print(results['source'],flush=True)
