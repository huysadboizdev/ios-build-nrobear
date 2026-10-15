using System;
using System.Reflection;
using System.Runtime.Serialization;
using UnityEngine;

public static class EquipmentAuraClientTests
{
    public static void Run()
    {
        foreach (string ns in new[] { "Game1", "Game2" })
        {
            Type ch=typeof(Game1.Char).Assembly.GetType(ns+".Char",true);
            Type frame=typeof(Game1.Char).Assembly.GetType(ns+".FrameImage",true);
            object c=FormatterServices.GetUninitializedObject(ch);
            Action<short> set=value => {
                var property=ch.GetProperty("idEff_Set_Item");
                if(property!=null)property.SetValue(c,value,null);else ch.GetField("idEff_Set_Item").SetValue(c,value);
            };
            set(5);
            ch.GetField("fraEff",BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic).SetValue(c,FormatterServices.GetUninitializedObject(frame));
            ch.GetField("fraEffSub",BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic).SetValue(c,FormatterServices.GetUninitializedObject(frame));
            set(8);
            if(ch.GetField("fraEff",BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic).GetValue(c)!=null || ch.GetField("fraEffSub",BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic).GetValue(c)!=null)throw new Exception(ns+" stale upgrade aura cache after level change");
            set(-1);
        }
        Debug.Log("EQUIPMENT_AURA_CLIENT_TESTS_PASS both clients");
    }
}
