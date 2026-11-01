#!/usr/bin/env python3
"""Offline structural validation; does not install a package or prove device trust."""
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import plistlib
import struct
import subprocess
import sys
import tarfile


def deb(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"!<arch>\n", "not a Debian ar archive"
    pos, members = 8, {}
    while pos < len(data):
        header = data[pos:pos + 60]
        assert len(header) == 60 and header[58:60] == b"`\n"
        name = header[:16].decode().strip().rstrip("/")
        size = int(header[48:58])
        assert name not in members
        members[name] = data[pos + 60:pos + 60 + size]
        assert len(members[name]) == size
        pos += 60 + size + (size % 2)
    assert members["debian-binary"] == b"2.0\n"
    assert len(members) == 3
    result = []
    for prefix in ("control.tar", "data.tar"):
        names = [x for x in members if x.startswith(prefix)]
        assert len(names) == 1
        # Produced package uses lzma; Python tarfile supports it directly.
        with tarfile.open(fileobj=io.BytesIO(members[names[0]]), mode="r:*") as tar:
            files, metadata = {}, []
            for item in tar:
                p = PurePosixPath(item.name)
                assert not p.is_absolute() and ".." not in p.parts
                name = str(p)
                if item.isdir(): continue
                marker = item.issym() and name == "Library/MobileSubstrate/DynamicLibraries/Tinge.dylib.roothidepatch" and item.linkname == "/usr/lib/DynamicPatches/AutoPatches.dylib"
                assert item.isfile() or marker, "unexpected link or special file"
                assert name not in files
                files[name] = item.linkname.encode() if marker else tar.extractfile(item).read()
                metadata.append((name, item.uid, item.gid, oct(item.mode)))
            result.append((files, metadata))
    return result


def verify_signature(blob, signature):
    offset, size = signature
    sig = blob[offset:offset + size]
    magic, length, count = struct.unpack_from(">III", sig)
    assert magic == 0xfade0cc0 and length <= size
    slots = {}
    for i in range(count):
        slot, off = struct.unpack_from(">II", sig, 12 + i * 8)
        magic, length = struct.unpack_from(">II", sig, off)
        assert off + length <= len(sig)
        slots[slot] = sig[off:off + length]
    directories = []
    for slot, cd in slots.items():
        if struct.unpack_from(">I", cd)[0] != 0xfade0c02: continue
        _, _, version, flags, hashes, identifier, special, pages, limit = struct.unpack_from(">9I", cd)
        hash_size, hash_type, platform, power = struct.unpack_from("4B", cd, 36)
        assert hash_type in (1, 2) and power <= 20
        hashfn = hashlib.sha1 if hash_type == 1 else hashlib.sha256
        assert hash_size == hashfn().digest_size
        page_size = 1 << power
        assert limit == offset and pages == (limit + page_size - 1) // page_size
        assert hashes + pages * hash_size <= len(cd)
        for i in range(pages):
            actual = hashfn(blob[i * page_size:min((i + 1) * page_size, limit)]).digest()
            assert actual == cd[hashes + i * hash_size:hashes + (i + 1) * hash_size], "code hash mismatch"
        for i in range(1, special + 1):
            stored = cd[hashes - i * hash_size:hashes - (i - 1) * hash_size]
            if any(stored):
                assert i in slots and stored == hashfn(slots[i]).digest(), "special slot mismatch"
        directories.append({"slot": slot, "hash": hashfn().name, "verified_pages": pages, "flags": flags})
    assert len(directories) >= 1
    return directories


def slices(blob):
    if blob[:4] == bytes.fromhex('cffaedfe'):
        subtype = struct.unpack_from('<I', blob, 8)[0]
        assert subtype == 0x80000002
        return {subtype:blob}
    assert blob[:4] == bytes.fromhex('cafebabe'), 'expected a Mach-O image' 
    count = struct.unpack_from('>I', blob, 4)[0]
    assert count == 2
    result = {}
    for i in range(count):
        cpu, subtype, offset, size, align = struct.unpack_from('>5I', blob, 8 + i*20)
        assert cpu == 0x100000c and subtype in (0, 0x80000002)
        assert offset % (1 << align) == 0 and offset + size <= len(blob)
        assert subtype not in result
        result[subtype] = blob[offset:offset+size]
    assert set(result) == {0, 0x80000002}
    return result


def inspect_slice(blob, subtype, expected_id, baseline=False, scheme="rootless"):
    header = struct.unpack_from('<8I', blob)
    assert header[:3] == (0xfeedfacf, 0x100000c, subtype) and header[3] in (6, 8)
    assert header[6] & 1, 'undefined dynamic lookup is not permitted'
    pos, deps, rpaths, signature, build, ident = 32, [], [], None, None, None
    text = {}
    for _ in range(header[4]):
        cmd, size = struct.unpack_from('<II', blob, pos)
        assert size >= 8 and pos + size <= 32 + header[5]
        if cmd in (0xc, 0xd, 0x18 | 0x80000000, 0x8000001c):
            start = pos + struct.unpack_from('<I', blob, pos+8)[0]
            name = blob[start:blob.index(0, start, pos+size)].decode()
            if cmd == 0xd: ident = name
            elif cmd == 0x8000001c: rpaths.append(name)
            else: deps.append(name)
        if cmd == 0x32:
            platform, minimum, sdk = struct.unpack_from('<III', blob, pos+8)
            assert platform == 2 and minimum <= 26 << 16
            build = {'platform':'iOS', 'minimum':f'{minimum>>16}.{(minimum>>8)&255}', 'sdk':f'{sdk>>16}.{(sdk>>8)&255}'}
        if cmd == 0x25:
            minimum, sdk = struct.unpack_from('<II', blob, pos+8)
            assert minimum <= 26 << 16
            build = {'platform':'iOS', 'minimum':f'{minimum>>16}.{(minimum>>8)&255}', 'sdk':f'{sdk>>16}.{(sdk>>8)&255}'}
        if cmd == 0x2c: assert struct.unpack_from('<I', blob, pos+16)[0] == 0
        if cmd == 0x1d: signature = struct.unpack_from('<II', blob, pos+8)
        if cmd == 0x19:
            for j in range(struct.unpack_from('<I', blob, pos+64)[0]):
                sect, seg, addr, length, offset = struct.unpack_from('<16s16sQQI', blob, pos+72+j*80)
                if seg.rstrip(b'\0') == b'__TEXT':
                    text[sect.rstrip(b'\0').decode()] = hashlib.sha256(blob[offset:offset+length]).hexdigest()
        pos += size
    assert pos == 32 + header[5]
    assert ident == expected_id, (ident, expected_id)
    assert build and signature
    assert not any('/Users/' in x for x in deps)
    if scheme == 'roothide':
        assert all(x.startswith(('/System/Library/', '/usr/lib/', '@loader_path/.jbroot/', '@rpath/')) for x in deps), deps
        if not baseline:
            assert '@loader_path/.jbroot/usr/lib/libroothide.dylib' in deps
            assert b'/var/jb' not in blob and b'libroot_dyn_' not in blob
            assert b'_Z6jbrootP8NSString' in blob, 'native NSString path API missing'
        if baseline:
            assert '@loader_path/.jbroot/Library/Frameworks' in rpaths
            assert '@loader_path/.jbroot/usr/lib' in rpaths
    else:
        assert not any('libroothide' in x for x in deps)
        assert all(x.startswith(('/System/Library/', '/usr/lib/', '/var/jb/usr/lib/', '@rpath/')) for x in deps), deps
        assert '/var/jb/Library/Frameworks' in rpaths and '/var/jb/usr/lib' in rpaths
    if not baseline: assert build['minimum'] == '15.0'
    return {'architecture':'arm64e' if subtype else 'arm64', 'cpu_subtype':hex(subtype),
        'build':build, 'install_name':ident, 'dependencies':deps, 'rpaths':rpaths,
        'text_sections_sha256':text, 'verified_code_directories':verify_signature(blob, signature)}


def macho(blob, ident, baseline=False, scheme="rootless"):
    images = slices(blob)
    assert set(images) == ({0,0x80000002} if baseline or scheme == 'rootless' else {0x80000002})
    return [inspect_slice(value, key, ident, baseline, scheme) for key,value in images.items()]


def main():
    package = Path(sys.argv[1])
    scheme = sys.argv[2]
    assert scheme in ('rootless', 'roothide')
    native = scheme == 'roothide'
    prefix = '' if native else 'var/jb/'
    (control, cm), (data, dm) = deb(package)
    assert set(control) == {'control'}, set(control)
    fields = dict(line.split(': ', 1) for line in control['control'].decode().splitlines() if ': ' in line)
    assert fields['Package'] == 'com.sahinkaa.velvetliquidglass'
    assert fields['Version'] == '1.0.0'
    assert fields['Name'] == 'Velvet - Liquid Glass'
    assert set(x.strip() for x in fields['Conflicts'].split(',')) == {'com.initwithframe.velvet','com.noisyflake.velvet2','com.sahinkaa.velvet26plus'}
    assert set(x.strip() for x in fields['Replaces'].split(',')) == {'com.noisyflake.velvet2','com.sahinkaa.velvet26plus'}
    assert fields['Architecture'] == ('iphoneos-arm64e' if native else 'iphoneos-arm64')
    assert fields['Author'] == 'NoisyFlake • sahinkaa'
    assert not any(x in control for x in ('preinst','postinst','prerm','postrm'))
    for name, uid, gid, mode in cm + dm:
        assert uid == gid == 0, (name, uid, gid)
        assert not int(mode, 8) & 0o022, (name, mode)
    assert len(data) == 19, sorted(data)
    assert all(x.startswith((prefix + 'Library/', prefix + 'usr/share/doc/com.sahinkaa.velvetliquidglass/')) for x in data)
    assert not any('Preferences.framework' in x or '.roothidepatch' in x for x in data)
    bundle = prefix + 'Library/PreferenceBundles/VelvetLiquidGlass.bundle/'
    filter_path = prefix + 'Library/MobileSubstrate/DynamicLibraries/VelvetLiquidGlass.plist'
    assert plistlib.loads(data[filter_path])['Filter']['Bundles'] == ['com.apple.springboard']
    for name in data:
        if name.endswith('.plist'):
            # OpenStep Preferences resources are parsed through macOS plutil.
            import tempfile
            with tempfile.NamedTemporaryFile(suffix='.plist') as f:
                f.write(data[name]); f.flush()
                subprocess.run(['/usr/bin/plutil', '-lint', f.name], check=True, stdout=subprocess.DEVNULL)
    binaries = {}
    for name, ident in [(prefix+'Library/MobileSubstrate/DynamicLibraries/VelvetLiquidGlass.dylib', ('@loader_path/.jbroot/Library/MobileSubstrate/DynamicLibraries/VelvetLiquidGlass.dylib' if native else '@rpath/VelvetLiquidGlass.dylib')),
                        (bundle+'VelvetLiquidGlass', ('/Library' if native else '/var/jb/Library')+'/PreferenceBundles/VelvetLiquidGlass.bundle/VelvetLiquidGlass')]:
        binaries[name] = macho(data[name], ident, scheme=scheme)
        for image in slices(data[name]).values():
            assert b'valueForKey:' not in image, 'unsafe KVC reader remains'
            assert b'1.0.0' in image, 'build identifier missing'
            assert b'VLG_LEGACY_PREFS_TEST_PATH' not in image
            assert b'VLG_PREFS_TEST_PATH' not in image, 'host test path branch in device binary'
    for image in slices(data[bundle+'VelvetLiquidGlass']).values():
        assert b'PSListController' not in image and b'PSSpecifier' not in image, 'legacy pane dependency remains'
        assert b'V26RootController' in image and b'tableView:cellForRowAtIndexPath:' in image, 'native data source missing'
    registration = plistlib.loads(data[prefix+'Library/PreferenceLoader/Preferences/VelvetLiquidGlass.plist'])
    assert registration['entry']['bundle'] == 'VelvetLiquidGlass'
    assert registration['entry']['detail'] == 'V26RootController'
    assert registration['entry']['label'] == 'Velvet - Liquid Glass'
    for image in slices(data[prefix+'Library/MobileSubstrate/DynamicLibraries/VelvetLiquidGlass.dylib']).values():
        for marker in (b'_notificationShortLookViewIfLoaded', b'_updateWithProvidedStaticContent', b'_setNotificationRequest:', b'_setContinuousCornerRadius:', b'paletteReady', b'firstPaint', b'VelvetLiquidGlass-', b'presentationState', b'hooks.prominentCompletion', b'hooks.subordinateCompletion', b'iconCompletion', b'outline.nativeSelector', b'hooks.booleanRequestSetter', b'hooks.backgroundAlpha', b'settledPalette', b'V26ForegroundRaster', b'foregroundMode', b'rasterRenders'):
            assert marker in image, 'retained runtime path missing'
        for marker in (b'testBanner.serviceInstalled',b'setDismissAutomatically:',b'withdrawNotificationRequest:'): assert marker in image
        assert b'_continuousRoundedCARectBezierPath:' not in image, 'unclamped outline helper remains'
        for marker in (b'stopAutomaticallyUpdatingView:',b'automaticallyUpdateView:withStyle:',b'abi.seamless.textRegistration',b'com.sahinkaa.velvetliquidglass/bannerFonts'):
            assert marker in image, 'text-provider ownership/font capture path missing'
        assert b'VLG_FONT_TEST_PATH' not in image
        assert b'com.sahinkaa.velvetliquidglass.plist' in image
        assert b'com.noisyflake.velvet2.plist' in image, 'legacy preferences migration path missing'
        assert b'testBanner.failure.' in image
        assert b'hooks.cellBorderLayout' not in image and b'hooks.classicMaterial' not in image, 'retired hook remains'
    for image in slices(data[bundle+'VelvetLiquidGlass']).values():
        for marker in (b'VLGLivePreviewView', b'VLGNumericSliderCell', b'initWithRecipe:supportsGlass:', b'preview.backend'):
            assert marker in image, 'new native preview/numeric controls missing'
        for marker in (b'paneHistory',b'testStatus',b'configureIdentifier:'): assert marker in image
        assert b'pushViewController:animated:' not in image, 'preview-recreating internal navigation remains'
        assert b'Velvet2PreviewView' not in image, 'retired preview remains'
        assert b'resetIdentifier:error:' in image and b'Reset This App' in image
        for marker in (b'Lock Screen / Notification Center',b'Lock Screen and Notification Center follow the dark Banner settings.',b'Tap to change the app.',b'preferredHeightForWidth:',b'Confirm',b'banner-fonts.plist'):
            assert marker in image, 'preview copy/layout/font cache or respring confirmation missing'
        for marker in (b'UIDocumentPickerViewController',b'Velvet - Liquid Glass settings.plist',b'Import Settings?',b'exportSettings',b'importSettings',b'initForExportingURLs:asCopy:',b'initForOpeningContentTypes:asCopy:'):
            assert marker in image, 'Files export/import path missing'
        assert b'Velvet - Liquid Glass Edition' not in image
        assert b'VLG_FONT_TEST_PATH' not in image
        assert b'VLG_TEMPLATE_TEST_PATH' not in image
        for marker in (b'Test Banner',b'goBack',b'lsncPreview',b'com.sahinkaa.velvetliquidglass/test-banner'): assert marker in image
        assert b'Preview uses the latest banner background' not in image
        assert b'minimumButton' not in image and b'maximumButton' not in image
        assert b'VLGBlurVisibility' not in image
    assert bundle+'CustomBorder.plist' not in data and bundle+'CustomLine.plist' not in data
    assert bundle+'CustomBannerBorder.plist' in data
    bg=plistlib.loads(data[bundle+'CustomBackground.plist'])
    assert not any(x.get('key')=='backgroundBlurHidden' for x in bg['items'])
    settings=plistlib.loads(data[bundle+'Settings.plist'])
    keys=[x.get('key') for x in settings['items']]
    assert keys.index('BannerBorder')<keys.index('Background')<keys.index('Shadow')
    assert 'appearance' not in keys  # The fixed header owns Light/Dark on every page.
    radius=next(x for x in settings['items'] if x.get('key')=='cornerRadiusPercent')
    assert float(radius['min'])==0 and float(radius['max'])==100
    assert any(x.get('key')=='Time' and x.get('label')=='Time' and x.get('systemIcon')=='clock' for x in settings['items'])
    assert not any(x.get('key')=='Date' or x.get('label')=='Date' for x in settings['items'])
    assert any(x.get('label')=='Text' for x in settings['items'])
    assert any(x.get('label')=='Corner Radius' and x.get('cell')=='PSGroupCell' for x in settings['items'])
    assert bundle+'github-mark@3x.png' in data
    root=plistlib.loads(data[bundle+'Root.plist'])
    assert any(x.get('label')=='Original Developer' for x in root['items'])
    assert any(x.get('label')=='Liquid Glass Edition Developer' for x in root['items'])
    actions=[x.get('action') for x in root['items'] if x.get('cell')!='PSGroupCell']
    reset_index=actions.index('resetSettings')
    assert actions[reset_index+1:reset_index+3]==['exportSettings','importSettings']
    assert any(x.get('action')=='github' and x.get('label')=='github.com/sahinkaa' for x in root['items'])
    for name,key in [('CustomShadow','shadowWidth'),('CustomBannerBorder','bannerBorderWidth')]:
        resource=plistlib.loads(data[bundle+name+'.plist'])
        assert float(next(x for x in resource['items'] if x.get('key')==key)['min'])==0
    for page,prefixKey in [('Background','background'),('BannerBorder','bannerBorder'),('Shadow','shadow'),('Title','title'),('Message','message'),('Time','date')]:
        resource=plistlib.loads(data[bundle+'Custom'+page+'.plist'])['items']
        opacity=next(i for i,x in enumerate(resource) if x.get('key')==prefixKey+'IconAlpha')
        shade=resource[opacity+1]
        assert shade['key']==prefixKey+'IconShade' and float(shade['min'])==-100 and float(shade['max'])==100
        assert shade.get('require')==resource[opacity].get('require') and float(shade['default'])==0
        for typeName,suffix in [('color','Color')]+([] if page=='Shadow' else [('gradient','Gradient')]):
            alpha=next(i for i,x in enumerate(resource) if x.get('key')==prefixKey+suffix+'Alpha')
            shadeRow=resource[alpha+1];colorRow=resource[alpha-1]
            assert colorRow['key']==prefixKey+suffix+('' if typeName=='color' else '2')
            assert float(resource[alpha]['default'])==100 and float(resource[alpha]['min'])==0 and float(resource[alpha]['max'])==100
            assert shadeRow['key']==prefixKey+suffix+'Shade' and float(shadeRow['default'])==0
            assert float(shadeRow['min'])==-100 and float(shadeRow['max'])==100
            assert resource[alpha]['require']==shadeRow['require']==prefixKey+'Enabled&'+prefixKey+'Type='+typeName
    border=plistlib.loads(data[bundle+'CustomBannerBorder.plist'])['items']
    assert not next(x for x in border if x.get('key')=='bannerBorderEnabled').get('cellSubtitleText')
    copyright_notice = data[prefix+'usr/share/doc/com.sahinkaa.velvetliquidglass/copyright']
    assert b'MIT License' in copyright_notice and b'Copyright (c) 2023 NoisyFlake' in copyright_notice and b'2014 Ole Krause-Sparmann' in copyright_notice
    assert not any('var/mobile/Library/Preferences' in name for name in data)
    glow = plistlib.loads(data[bundle+'CustomShadow.plist'])
    assert any(x.get('key') == 'shadowEnabled' and not x.get('require') for x in glow['items'])
    info = plistlib.loads(data[bundle+'Info.plist'])
    assert info['CFBundleDisplayName']=='Velvet - Liquid Glass'
    assert sum(x.get('label')=='Liquid Glass Edition Developer' for x in root['items'])==1
    assert info['CFBundleExecutable'] == 'VelvetLiquidGlass'
    assert info['CFBundleIdentifier'] == 'com.sahinkaa.velvetliquidglass'
    time_page=plistlib.loads(data[bundle+'CustomTime.plist'])
    assert time_page['title']=='Time'
    assert any(x.get('label')=='Enable Time' for x in time_page['items'])
    assert any(x.get('cellSubtitleText')=='Use a custom time color' for x in time_page['items'])
    assert 'CustomDate.plist' not in {x.removeprefix(bundle) for x in data if x.startswith(bundle)}
    assert not any('/Velvet2.' in x or '/Velvet2/' in x or 'velvet26plus' in x for x in data)
    assert info['NSPrincipalClass'] == 'V26RootController'
    assert info['CFBundleVersion'] == '1.0.0'
    print(json.dumps({'package': package.name, 'scheme': scheme, 'sha256': hashlib.sha256(package.read_bytes()).hexdigest(), 'control': fields, 'payload_files': sorted(data), 'binaries': binaries, 'result': 'PASS; offline validation only'}, indent=2))

if __name__ == '__main__': main()
