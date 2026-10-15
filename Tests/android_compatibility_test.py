from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/'Assets/Editor/ClientDistributionBuild.cs').read_text(encoding='utf-8-sig')
assert 'PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP)' in s, 'Android release must support native ARM64 via IL2CPP'
assert 'AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64' in s, 'Keep both 32bit and 64bit devices supported'
assert 'PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel23' in s, 'Android6 minimum must be explicit'
print('Android build configuration PASS')
