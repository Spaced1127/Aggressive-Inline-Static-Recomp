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

        // With no log and no profile, the DualSense default is the fallback.
        string clean = Path.Combine(Path.GetTempPath(),
            "gile-controller-clean-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(Path.Combine(clean, "logs"));
        ensure.Invoke(null, new object[] { clean, root });
        string cleanProfile = Path.Combine(clean, "Config", "GCPadNew.ini");
        Check(File.Exists(cleanProfile), "default profile created");
        Check(File.ReadAllText(cleanProfile).Contains(
              "Device = SDL/0/DualSense Wireless Controller"),
            "default profile is DualSense");
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
