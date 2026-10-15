using System;
using System.Reflection;
using UnityEngine;

public static class BlackPowerAuraRegression
{
    const BindingFlags Flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static | BindingFlags.Instance;
    static int checks;
    static void Check(bool value, string message) { checks++; if (!value) throw new Exception(message); }
    static void Set(Type type, object target, string field, object value)
    {
        FieldInfo info = type.GetField(field, Flags);
        if (value != null && !info.FieldType.IsInstanceOfType(value)) value = Convert.ChangeType(value, info.FieldType);
        info.SetValue(target, value);
    }
    static object Call(Type type, string name, params object[] args) { return type.GetMethod(name, Flags).Invoke(null, args); }

    public static void Run()
    {
        checks = 0;
        foreach (string ns in new[] { "Game1", "Game2" })
        {
            Assembly assembly = typeof(Game1.Char).Assembly;
            Type helper = assembly.GetType(ns + ".BlackPowerAura");
            Check(helper != null, ns + ": black aura helper missing (expected before implementation)");
            long[] powers = { -1L, 0L, 69999999999L, 70000000000L, 70000000001L, 100000000000L, long.MaxValue };
            foreach (long power in powers)
                Check((bool)Call(helper, "ReachesThreshold", power) == (power >= 70000000000L), ns + ": threshold " + power);
            VerifyEligibility(assembly, ns, helper);
            VerifyFrames(assembly, ns, helper);
        }
        Debug.Log("BLACK_POWER_AURA_THRESHOLD_PASS checks=" + checks);
    }

    static void VerifyEligibility(Assembly assembly, string ns, Type helper)
    {
        Type actorType = assembly.GetType(ns + ".Char");
        Type canvas = assembly.GetType(ns + ".GameCanvas");
        Type mod = assembly.GetType(ns + ".ModFunc");
        object actor = Activator.CreateInstance(actorType);
        string[] savedFields = { "myChar", "myPet", "isPaintAura", "isPaintAura2" };
        object[] saved = new object[savedFields.Length];
        for (int i = 0; i < saved.Length; i++) saved[i] = actorType.GetField(savedFields[i], Flags).GetValue(null);
        object previousLow = canvas.GetField("lowGraphic", Flags).GetValue(null);
        object previousReduce = mod.GetField("GiamDungLuong", Flags).GetValue(null);
        object previousPanel = canvas.GetField("panel", Flags).GetValue(null);
        try
        {
            Set(actorType, null, "myPet", null);
            Set(actorType, null, "isPaintAura", true);
            Set(actorType, null, "isPaintAura2", true);
            Set(canvas, null, "lowGraphic", false);
            Set(canvas, null, "panel", null);
            Set(mod, null, "GiamDungLuong", false);
            Set(actorType, actor, "me", true);
            Set(actorType, actor, "cPower", 70000000000L);
            Set(actorType, actor, "statusMe", 1);
            Set(actorType, actor, "idAuraEff", -1);
            Check((bool)Call(helper, "IsEligible", actor), ns + ": own character at threshold");
            Set(actorType, actor, "cPower", 69999999999L);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": own below threshold");
            Set(actorType, actor, "cPower", 70000000000L);
            Set(actorType, actor, "me", false);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": peer power must not be inferred");
            Check(actorType.GetField("myPet", Flags).GetValue(null) == null, ns + ": peer check must not create a pet");
            object petInfo = Activator.CreateInstance(actorType);
            Set(actorType, null, "myPet", petInfo);
            Set(actorType, petInfo, "charID", -42);
            Set(actorType, petInfo, "cPower", 70000000000L);
            Set(actorType, actor, "charID", -42);
            Set(actorType, actor, "isPet", true);
            Set(actorType, actor, "cPower", 0L);
            Check((bool)Call(helper, "IsEligible", actor), ns + ": rendered pet uses matching known pet info");
            Set(actorType, actor, "charID", -43);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": unrelated pet does not inherit power");
            object owner = Activator.CreateInstance(actorType);
            Set(actorType, null, "myChar", owner);
            Set(actorType, owner, "charID", 42);
            Set(actorType, petInfo, "charID", 0);
            Set(actorType, actor, "charID", -42);
            Check((bool)Call(helper, "IsEligible", actor), ns + ": server disciple ID matches owner with ID-less pet info");
            Set(actorType, actor, "charID", -43);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": other owner's disciple stays unchanged");
            Set(actorType, actor, "me", true);
            Set(actorType, actor, "cPower", 70000000000L);
            foreach (string field in new[] { "isHide", "isCopy", "isMiniPet" })
            {
                Set(actorType, actor, field, true);
                Check(!(bool)Call(helper, "IsEligible", actor), ns + ": suppress " + field);
                Set(actorType, actor, field, false);
            }
            Set(actorType, actor, "isMonkey", 1);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": suppress monkey");
            Set(actorType, actor, "isMonkey", 0);
            foreach (int state in new[] { 2, 3, 4, 7, 8, 9, 10, 12, 13 })
            {
                Set(actorType, actor, "statusMe", state);
                Check((bool)Call(helper, "IsEligible", actor), ns + ": black aura stays visible while alive state " + state);
            }
            foreach (int state in new[] { 5, 14, 15 })
            {
                Set(actorType, actor, "statusMe", state);
                Check(!(bool)Call(helper, "IsEligible", actor), ns + ": suppress state " + state);
            }
            Set(actorType, actor, "statusMe", 1);
            Set(actorType, null, "isPaintAura2", false);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": respect power aura setting");
            Set(actorType, null, "isPaintAura2", true);
            Set(canvas, null, "lowGraphic", true);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": respect low graphics");
            Set(canvas, null, "lowGraphic", false);
            Set(mod, null, "GiamDungLuong", true);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": respect reduce resources");
            Set(mod, null, "GiamDungLuong", false);
            Set(actorType, actor, "idAuraEff", 1);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": special aura takes priority");
            Set(actorType, null, "isPaintAura", false);
            Check((bool)Call(helper, "IsEligible", actor), ns + ": disabled special aura permits black power aura");
            try
            {
                actorType.GetMethod("paintAuraBehind", Flags).Invoke(actor, new object[] { null });
                checks++;
            }
            catch (TargetInvocationException error)
            {
                throw new Exception(ns + ": disabled special aura must not paint behind black power aura", error.InnerException);
            }
            Set(actorType, actor, "me", false);
            Set(actorType, actor, "charID", -42);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": rendered pet keeps special aura priority even with local option disabled");
            Set(actorType, actor, "idAuraEff", -1);
            Call(actorType, "clearMyChar");
            Check(actorType.GetField("myPet", Flags).GetValue(null) == null, ns + ": logout clears old account pet power");
            object newOwner = Activator.CreateInstance(actorType);
            Set(actorType, newOwner, "charID", 43);
            Set(actorType, null, "myChar", newOwner);
            Set(actorType, actor, "charID", -43);
            Check(!(bool)Call(helper, "IsEligible", actor), ns + ": new account cannot inherit previous pet aura");
        }
        finally
        {
            for (int i = 0; i < saved.Length; i++) Set(actorType, null, savedFields[i], saved[i]);
            Set(canvas, null, "lowGraphic", previousLow);
            Set(canvas, null, "panel", previousPanel);
            Set(mod, null, "GiamDungLuong", previousReduce);
        }
    }

    static void VerifyFrames(Assembly assembly, string ns, Type helper)
    {
        Type graphics = assembly.GetType(ns + ".mGraphics");
        Type main = assembly.GetType(ns + ".Main");
        object previousZoom = graphics.GetField("zoomLevel", Flags).GetValue(null);
        object previousRes = main.GetField("res", Flags).GetValue(null);
        try
        {
            Set(main, null, "res", "res");
            foreach (int zoom in new[] { 1, 2, 3, 4, 2 })
            {
                Set(graphics, null, "zoomLevel", zoom);
                Check((bool)Call(helper, "EnsureFrames"), ns + ": texture load zoom " + zoom);
                Array images = (Array)helper.GetField("frames", Flags).GetValue(null);
                Check(images.Length == 7, ns + ": all seven frames");
                foreach (object image in images)
                {
                    Type imageType = image.GetType();
                    int width = (int)imageType.GetField("w", Flags).GetValue(image);
                    int height = (int)imageType.GetField("h", Flags).GetValue(image);
                    Check(width == 62 * zoom && height == 82 * zoom, ns + ": scaled frame dimensions at zoom " + zoom);
                }
                Check((bool)Call(helper, "EnsureFrames"), ns + ": cache reuse zoom " + zoom);
                Check(ReferenceEquals(images, helper.GetField("frames", Flags).GetValue(null)), ns + ": no repeated frame allocation");
            }
            Set(graphics, null, "zoomLevel", 3);
            Set(main, null, "res", "__missing_black_aura_regression__");
            Check(!(bool)Call(helper, "EnsureFrames"), ns + ": missing textures fall back safely");
            Set(main, null, "res", "res");
            Check(!(bool)Call(helper, "EnsureFrames"), ns + ": no repeated reload after failed attempt");
            Set(graphics, null, "zoomLevel", 4);
            Check((bool)Call(helper, "EnsureFrames"), ns + ": recover on a new zoom");
            Texture2D resourceTexture = Resources.Load<Texture2D>("res/x4/poweraura/black/0");
            Set(graphics, null, "zoomLevel", 1);
            Check((bool)Call(helper, "EnsureFrames"), ns + ": resize after loading shared x4");
            Check(resourceTexture != null && Resources.Load<Texture2D>("res/x4/poweraura/black/0") == resourceTexture,
                ns + ": cache replacement never destroys shared resource textures");
        }
        finally
        {
            Set(graphics, null, "zoomLevel", previousZoom);
            Set(main, null, "res", previousRes);
        }
    }
}
