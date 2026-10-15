using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class ClientDistributionBuild
{
    public static void Verify()
    {
        ClientBranding.Apply();
        EquipmentAuraClientTests.Run();
        BlackPowerAuraRegression.Run();
        NpcImageDecodeCases.Run();
        HighSpeedSkillRegression.Run();
        ReceiveQueueBudgetRegression.Run();
    }
    public static void PC() { Build(BuildTarget.StandaloneWindows64); }
    public static void Android() { Build(BuildTarget.Android); }
    static void Build(BuildTarget target)
    {
        string output = Environment.GetEnvironmentVariable("NRO_DISTRIBUTION_OUTPUT");
        if (String.IsNullOrEmpty(output)) throw new Exception("NRO_DISTRIBUTION_OUTPUT required");
        var scenes = EditorBuildSettings.scenes.Where(s => s.enabled).Select(s => s.path).ToArray();
        if (scenes.Length != 2 || !scenes[0].EndsWith("/NROL.unity") || !scenes[1].EndsWith("/NROL1.unity")) throw new Exception("Both original client scenes required");
        Verify();
        string folder = Path.Combine(output, target == BuildTarget.Android ? "Android" : "Windows");
        Directory.CreateDirectory(folder);
        string file = Path.Combine(folder, target == BuildTarget.Android ? "NRO.apk" : "NRO.exe");
        if (File.Exists(file)) throw new Exception("Refusing to overwrite an existing distribution");
        if (target == BuildTarget.Android) {
            EditorUserBuildSettings.buildAppBundle = false;
            EditorUserBuildSettings.exportAsGoogleAndroidProject = false;
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARMv7 | AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel23;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel34;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = true;
        } else {
            PlayerSettings.SetScriptingBackend(BuildTargetGroup.Standalone, ScriptingImplementation.Mono2x);
        }
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions { scenes = scenes, locationPathName = file, target = target, options = BuildOptions.None });
        string result = "Result="+report.summary.result+"\nErrors="+report.summary.totalErrors+"\nWarnings="+report.summary.totalWarnings+"\nBytes="+report.summary.totalSize+"\nServer="+Management.IpServer+"\nScenes="+String.Join(",",scenes)+"\n";
        result += "Backend=" + PlayerSettings.GetScriptingBackend(target == BuildTarget.Android ? BuildTargetGroup.Android : BuildTargetGroup.Standalone) + "\n";
        if (target == BuildTarget.Android) result += "Architectures=" + PlayerSettings.Android.targetArchitectures + "\n";
        File.WriteAllText(Path.Combine(folder,"build-result.txt"),result);
        File.WriteAllText(Path.Combine(folder,"signing.txt"), target == BuildTarget.Android
            ? (PlayerSettings.Android.useCustomKeystore ? "Custom release keystore\n" : "Unity development keystore; keep a stable release keystore for future public updates.\n")
            : "Windows executable is unsigned.\n");
        if (report.summary.result != BuildResult.Succeeded || report.summary.totalErrors != 0) throw new Exception("Client distribution build failed: "+result);
        Debug.Log("NRO_DISTRIBUTION_SUCCEEDED "+target+" "+file);
    }
}
