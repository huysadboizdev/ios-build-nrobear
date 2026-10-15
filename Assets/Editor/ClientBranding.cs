using System;
using System.Linq;
using UnityEditor;
using UnityEditor.Android;
using UnityEngine;

public static class ClientBranding
{
    public static void Apply()
    {
        const string path = "Assets/Branding/iconlogo.png";
        AssetDatabase.ImportAsset(path, ImportAssetOptions.ForceSynchronousImport);
        var icon = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        if (icon == null) throw new Exception("3-in-1 application icon missing");
        PlayerSettings.SetIconsForTargetGroup(BuildTargetGroup.Unknown, new[] { icon });
        SetLegacy(BuildTargetGroup.Standalone, icon);
        SetLegacy(BuildTargetGroup.Android, icon);
        // Replace stale platform overrides as well as the default/legacy slots.
        SetPlatform(AndroidPlatformIconKind.Legacy, icon, null);
        SetPlatform(AndroidPlatformIconKind.Round, icon, null);
        const string backgroundPath = "Assets/Branding/AndroidIconBackground.asset";
        var background = AssetDatabase.LoadAssetAtPath<Texture2D>(backgroundPath);
        if (background == null)
        {
            background = new Texture2D(2, 2, TextureFormat.RGBA32, false);
            background.SetPixels(Enumerable.Repeat(new Color(0.18f, 0.41f, 0.62f, 1), 4).ToArray());
            background.Apply();
            AssetDatabase.CreateAsset(background, backgroundPath);
        }
        SetPlatform(AndroidPlatformIconKind.Adaptive, icon, background);
        AssetDatabase.SaveAssets();
        Debug.Log("CLIENT_BRANDING_APPLIED " + AssetDatabase.AssetPathToGUID(path));
    }

    static void SetLegacy(BuildTargetGroup group, Texture2D icon)
    {
        int count = PlayerSettings.GetIconSizesForTargetGroup(group).Length;
        if (count > 0) PlayerSettings.SetIconsForTargetGroup(group, Enumerable.Repeat(icon, count).ToArray());
    }

    static void SetPlatform(PlatformIconKind kind, Texture2D icon, Texture2D background)
    {
        var slots = PlayerSettings.GetPlatformIcons(BuildTargetGroup.Android, kind);
        foreach (var slot in slots)
        {
            slot.SetTexture(background == null ? icon : background, 0);
            if (slot.maxLayerCount > 1) slot.SetTexture(icon, 1);
        }
        PlayerSettings.SetPlatformIcons(BuildTargetGroup.Android, kind, slots);
    }
}
