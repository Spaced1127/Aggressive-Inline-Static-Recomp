using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;

internal static class ControllerSelfTest
{
    private static int _failures;

    private static int Main()
    {
        string root = @"H:\Projects\Agressive Inline Static Recompile";
        string temp = Path.Combine(Path.GetTempPath(),
            "gile-controller-selftest-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(temp, "logs"));

        // A realistic log tail: DualSense first, then an Xbox pad, then a
        // keyboard. The launcher should keep both pads, skip the keyboard, and
        // use the last pad as the auto-detected device.
        File.WriteAllText(Path.Combine(temp, "logs", "dolphin.log"),
            "41:23:470 InputCommon\\ControllerInterface\\ControllerInterface.cpp:273 " +
            "N[CI]: Added device: SDL/0/DualSense Wireless Controller\n" +
            "41:23:610 InputCommon\\ControllerInterface\\ControllerInterface.cpp:310 " +
            "N[CI]: Removed device: DInput/0/DualSense Wireless Controller\n" +
            "41:24:100 InputCommon\\ControllerInterface\\ControllerInterface.cpp:273 " +
            "N[CI]: Added device: SDL/0/Xbox Wireless Controller\n" +
            "41:24:200 InputCommon\\ControllerInterface\\ControllerInterface.cpp:273 " +
            "N[CI]: Added device: SDL/0/Keyboard\n");

        Assembly asm = Assembly.LoadFrom(
            Path.Combine(root, "build", "launcher", "gile-launcher.exe"));
        Type program = asm.GetType("Program");
        if (program == null)
        {
            Fail("Program type not found");
            return Finish(temp);
        }

        MethodInfo detect = Method(program, "DetectControllerDevices");
        MethodInfo detectOne = Method(program, "DetectControllerDevice");
        MethodInfo presetFor = Method(program, "ControllerPresetForDevice");
        MethodInfo presetDevice = Method(program, "ControllerPresetDevice");
        MethodInfo ensure = Method(program, "EnsureConfig");
        MethodInfo write = Method(program, "WriteControllerProfile");

        List<string> devices = (List<string>)detect.Invoke(null, new object[] { temp });
        Check(devices.Count == 2, "two pads detected (got " + devices.Count + ")");
        Check(devices[0] == "SDL/0/DualSense Wireless Controller", "DualSense preserved");
        Check(devices[1] == "SDL/0/Xbox Wireless Controller", "Xbox detected last");

        string last = (string)detectOne.Invoke(null, new object[] { temp });
        Check(last == "SDL/0/Xbox Wireless Controller", "last device is Xbox");

        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Xbox Series X Controller" }) == "xbox-series",
            "Xbox Series mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Xbox One Controller" }) == "xbox-one",
            "Xbox One mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Xbox 360 Controller" }) == "xbox360",
            "Xbox 360 mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Xbox Wireless Controller" }) == "xbox",
            "Xbox Wireless mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/PS4 Controller" }) == "dualshock4",
            "DualShock 4 mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/PS3 Controller" }) == "dualshock3",
            "DualShock 3 mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Nintendo Switch Pro Controller" }) == "switch-pro",
            "Switch Pro mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/DualSense Wireless Controller" }) == "dualsense",
            "DualSense mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/8BitDo Pro 2" }) == "8bitdo",
            "8BitDo mapping");
        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Something Else" }) == "generic",
            "unknown pad falls back to generic");

        Check((string)presetDevice.Invoke(null, new object[] { "xbox" }) ==
              "SDL/0/Xbox Wireless Controller", "Xbox default name");
        Check((string)presetDevice.Invoke(null, new object[] { "switch-pro" }) ==
              "SDL/0/Nintendo Switch Pro Controller", "Switch default name");

        // No profile yet, log says Xbox: EnsureConfig should create an Xbox
        // profile with the exact detected name, not the DualSense default.
        ensure.Invoke(null, new object[] { temp, root });
        string profile = Path.Combine(temp, "Config", "GCPadNew.ini");
        Check(File.Exists(profile), "profile created");
        string profileText = File.Exists(profile) ? File.ReadAllText(profile) : string.Empty;
        Check(profileText.Contains("Device = SDL/0/Xbox Wireless Controller"),
            "profile uses detected Xbox name");
        Check(profileText.Contains("[GCPad1]"), "profile section");
        Check(profileText.Contains("Buttons/A = `Button A`"), "profile face buttons");
        Check(profileText.Contains("Triggers/L-Analog = `Trigger L`"), "profile analog triggers");
        Check(profileText.Contains("Rumble/Motor = `Motor L` | `Motor R`"), "profile rumble");

        // Applying a preset with a different controller id rewrites only the
        // Device line and keeps the full mapping.
        string switchProfile = Path.Combine(temp, "Config", "GCPadNew.switch.ini");
        write.Invoke(null, new object[]
        {
            Path.Combine(root, "defaults", "GCPadNew.switch-pro.ini"),
            switchProfile,
            "SDL/1/Nintendo Switch Pro Controller"
        });
        string switchText = File.ReadAllText(switchProfile);
        Check(switchText.Contains("Device = SDL/1/Nintendo Switch Pro Controller"),
            "custom SDL id preserved");
        Check(switchText.Contains("Buttons/A = `Button A`"), "switch mapping kept");

        // Every shipped preset must exist and carry the full mapping.
        string[] presets =
        {
            "dualsense", "dualshock4", "dualshock3", "xbox", "xbox-series",
            "xbox-one", "xbox360", "xbox-generic", "switch-pro", "steam",
            "8bitdo", "generic"
        };
        foreach (string preset in presets)
        {
            string path = Path.Combine(root, "defaults", "GCPadNew." + preset + ".ini");
            Check(File.Exists(path), "preset exists: " + preset);
            if (!File.Exists(path))
                continue;
            string text = File.ReadAllText(path);
            Check(text.Contains("Device = SDL/0/"), "preset device: " + preset);
            Check(text.Contains("Buttons/A = `Button A`"), "preset mapping: " + preset);
            Check(text.Contains("Triggers/R-Analog = `Trigger R`"), "preset triggers: " + preset);
        }

        Check((string)presetFor.Invoke(null, new object[] { "SDL/0/Pro Controller" }) == "switch-pro",
            "bare Pro Controller mapping");

        // Existing profiles must not be replaced just because the last log
        // mentions a different pad.
        File.WriteAllText(Path.Combine(temp, "logs", "dolphin.log"),
            "41:24:100 InputCommon\\ControllerInterface\\ControllerInterface.cpp:273 " +
            "N[CI]: Added device: SDL/0/DualSense Wireless Controller\n");
        ensure.Invoke(null, new object[] { temp, root });
        string kept = File.ReadAllText(profile);
        Check(kept.Contains("Device = SDL/0/Xbox Wireless Controller"),
            "existing profile kept on later launch");

        // With no log and no profile the launcher must leave GCPadNew.ini
        // absent so the runner can auto-detect the first SDL pad. This is the
        // RecompLauncher path: it never opens the controller page.
        string clean = Path.Combine(Path.GetTempPath(),
            "gile-controller-clean-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(clean, "logs"));
        ensure.Invoke(null, new object[] { clean, root });
        string cleanProfile = Path.Combine(clean, "Config", "GCPadNew.ini");
        Check(!File.Exists(cleanProfile), "no default controller profile pre-seeded");

        string cleanDolphin = Path.Combine(clean, "Config", "Dolphin.ini");
        string cleanConfig = Path.Combine(clean, "config.ini");
        Check(File.Exists(cleanDolphin), "default Dolphin.ini created");
        Check(File.Exists(cleanConfig), "default config.ini created");
        string cleanDolphinText = File.ReadAllText(cleanDolphin);
        Check(cleanDolphinText.Contains("RenderWindowWidth = "),
            "default window width written");
        Check(cleanDolphinText.Contains("RenderWindowHeight = "),
            "default window height written");
        string cleanConfigText = File.ReadAllText(cleanConfig);
        Check(cleanConfigText.Contains("aspect=wide"), "new config is 16:9");
        Check(cleanConfigText.Contains("widescreen_hack=true"),
            "new config enables widescreen hack");
        string cleanLauncher = Path.Combine(clean, "launcher.ini");
        Check(File.Exists(cleanLauncher) &&
              File.ReadAllText(cleanLauncher).Contains("AspectMigratedV004 = true"),
            "migration marker written");

        // A v0.0.3 config (1920x1080, Auto, hack off) should move to
        // 2560x1440 16:9 on a 1440p display, but only once.
        MethodInfo defaultRes = Method(program, "DefaultResolutionValue");
        string preferred = (string)defaultRes.Invoke(null, null);
        string legacy = Path.Combine(Path.GetTempPath(),
            "gile-controller-legacy-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(legacy, "logs"));
        string legacyConfig = Path.Combine(legacy, "config.ini");
        File.WriteAllText(legacyConfig,
            "[Video]\nresolution=1920x1080\naspect=auto\nwidescreen_hack=false\n");
        ensure.Invoke(null, new object[] { legacy, root });
        string legacyText = File.ReadAllText(legacyConfig);
        if (preferred == "2560x1440")
        {
            Check(legacyText.Contains("resolution = 2560x1440"),
                "legacy resolution migrated to 1440p");
            Check(legacyText.Contains("aspect = wide"),
                "legacy aspect migrated to 16:9");
            Check(legacyText.Contains("widescreen_hack = true"),
                "legacy widescreen hack migrated on");
        }

        // A later explicit Auto/off choice must survive the next launch.
        File.WriteAllText(legacyConfig,
            "[Video]\nresolution=1920x1080\naspect=auto\nwidescreen_hack=false\n");
        Directory.Delete(Path.Combine(legacy, "Config"), true);
        ensure.Invoke(null, new object[] { legacy, root });
        MethodInfo getIni = Method(program, "GetIniKey");
        string keptAspect = (string)getIni.Invoke(null,
            new object[] { legacyConfig, "Video", "aspect", "" });
        string keptHack = (string)getIni.Invoke(null,
            new object[] { legacyConfig, "Video", "widescreen_hack", "" });
        Check(keptAspect == "auto" && keptHack == "false",
            "later 4:3 choice not overridden");
        try { Directory.Delete(legacy, true); }
        catch { }

        // 16:9 display sizing: the runner key 640x528 is the 1x EFB scale,
        // the window/output size is 640x360.
        MethodInfo applyDisplay = Method(program, "ApplyDisplayResolution");
        string sizeProbe = Path.Combine(clean, "Config", "Dolphin-size.ini");
        File.WriteAllText(sizeProbe, "[Display]\nFullscreen = False\n");
        applyDisplay.Invoke(null, new object[] { sizeProbe, "640x528" });
        string sizeText = File.ReadAllText(sizeProbe);
        Check(sizeText.Contains("RenderWindowWidth = 640"), "1x output width");
        Check(sizeText.Contains("RenderWindowHeight = 360"), "1x output height 16:9");

        applyDisplay.Invoke(null, new object[] { sizeProbe, "2560x1440" });
        sizeText = File.ReadAllText(sizeProbe);
        Check(sizeText.Contains("RenderWindowWidth = 2560"), "1440p output width");
        Check(sizeText.Contains("RenderWindowHeight = 1440"), "1440p output height");

        applyDisplay.Invoke(null, new object[] { sizeProbe, "1280x720" });
        sizeText = File.ReadAllText(sizeProbe);
        Check(sizeText.Contains("RenderWindowWidth = 1280"), "720p output width");
        Check(sizeText.Contains("RenderWindowHeight = 720"), "720p output height");

        try { Directory.Delete(clean, true); }
        catch { }

        return Finish(temp);
    }

    private static MethodInfo Method(Type type, string name)
    {
        MethodInfo method = type.GetMethod(name,
            BindingFlags.NonPublic | BindingFlags.Static);
        if (method == null)
            throw new InvalidOperationException("missing method: " + name);
        return method;
    }

    private static void Check(bool condition, string label)
    {
        Console.WriteLine((condition ? "PASS " : "FAIL ") + label);
        if (!condition)
            _failures++;
    }

    private static void Fail(string label)
    {
        Console.WriteLine("FAIL " + label);
        _failures++;
    }

    private static int Finish(string temp)
    {
        try { Directory.Delete(temp, true); }
        catch { }
        Console.WriteLine(_failures == 0 ? "controller self-test: PASS" :
                          "controller self-test: " + _failures + " failure(s)");
        return _failures == 0 ? 0 : 1;
    }
}
