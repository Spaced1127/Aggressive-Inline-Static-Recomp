using System;
using System.IO;
using System.Reflection;

// Canonical controller system: launcher-side checks.
// The launcher must not create or rewrite GCPadNew.ini, must write the
// controller_class override, and must not carry the old preset tables.
internal static class ControllerSelfTest
{
    private static int _failures;

    private static void Check(bool condition, string label)
    {
        Console.WriteLine((condition ? "PASS " : "FAIL ") + label);
        if (!condition)
            _failures++;
    }

    private static int Main()
    {
        string root = @"H:\Projects\Agressive Inline Static Recompile";
        string temp = Path.Combine(Path.GetTempPath(),
            "gile-controller-selftest-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(temp);

        string launcher = Path.Combine(root, "build", "launcher", "gile-launcher.exe");
        if (!File.Exists(launcher))
        {
            Console.WriteLine("FAIL launcher binary missing: " + launcher);
            return 1;
        }

        Assembly asm = Assembly.LoadFrom(launcher);
        Type program = asm.GetType("Program");
        if (program == null)
        {
            Console.WriteLine("FAIL Program type not found");
            return 1;
        }

        MethodInfo ensure = program.GetMethod("EnsureConfig",
            BindingFlags.NonPublic | BindingFlags.Static);
        Check(ensure != null, "EnsureConfig found");
        if (ensure == null)
            return 1;

        ensure.Invoke(null, new object[] { temp, root });

        string config = Path.Combine(temp, "config.ini");
        string profile = Path.Combine(temp, "Config", "GCPadNew.ini");
        Check(File.Exists(config), "config.ini created");
        Check(File.ReadAllText(config).Contains("controller_class=auto"),
              "controller_class=auto written");
        Check(!File.Exists(profile), "GCPadNew.ini is not pre-seeded");

        // A player's existing profile must survive a launcher start byte for byte.
        Directory.CreateDirectory(Path.GetDirectoryName(profile));
        string existing = "[GCPad1]\nDevice = SDL/0/Xbox One Controller\nButtons/A = `Button A`\n";
        File.WriteAllText(profile, existing);
        string before = File.ReadAllText(profile);
        ensure.Invoke(null, new object[] { temp, root });
        Check(File.ReadAllText(profile) == before, "existing GCPadNew.ini is untouched");

        // Old per-device preset machinery must be gone.
        Check(program.GetMethod("ControllerPresetForDevice",
                  BindingFlags.NonPublic | BindingFlags.Static) == null,
              "no per-device preset lookup");
        Check(program.GetMethod("WriteControllerProfile",
                  BindingFlags.NonPublic | BindingFlags.Static) == null,
              "no profile writer");
        Check(program.GetMethod("DetectControllerDevices",
                  BindingFlags.NonPublic | BindingFlags.Static) == null,
              "no log-based device table");

        try { Directory.Delete(temp, true); } catch { }
        Console.WriteLine(_failures == 0 ? "All launcher controller checks passed"
                                         : _failures + " launcher controller check(s) failed");
        return _failures == 0 ? 0 : 1;
    }
}