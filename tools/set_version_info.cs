using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class SetVersionInfo
{
    private const uint RT_VERSION = 16;
    // The C# compiler writes its version resource with language 0 and the
    // "000004B0" string table. Updating that exact resource keeps Explorer and
    // the VersionInfo API reading the new strings.
    private const ushort Lang = 0x0000;
    private const ushort Codepage = 0x04B0; // Unicode

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr BeginUpdateResource(string fileName, bool deleteExisting);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool UpdateResource(IntPtr update, IntPtr type, IntPtr name,
        ushort language, byte[] data, uint size);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool EndUpdateResource(IntPtr update, bool discard);

    private static int Main(string[] args)
    {
        if (args.Length < 3)
        {
            Console.Error.WriteLine(
                "usage: set_version_info <exe> <version> <description> [product] [company]");
            return 2;
        }
        string path = Path.GetFullPath(args[0]);
        string version = args[1];
        string description = args[2];
        string product = args.Length > 3 ? args[3] : description;
        string company = args.Length > 4 ? args[4] : "Aggressive Inline Recomp";

        Version parsed;
        if (!Version.TryParse(version, out parsed))
        {
            Console.Error.WriteLine("invalid version: " + version);
            return 2;
        }

        string exeName = Path.GetFileName(path);
        Dictionary<string, string> strings = new Dictionary<string, string>
        {
            { "CompanyName", company },
            { "FileDescription", description },
            { "FileVersion", version },
            { "InternalName", Path.GetFileNameWithoutExtension(path) },
            { "LegalCopyright", "No game data included." },
            { "OriginalFilename", exeName },
            { "ProductName", product },
            { "ProductVersion", version },
        };

        byte[] data = BuildVersionResource(parsed, strings);
        IntPtr update = BeginUpdateResource(path, false);
        if (update == IntPtr.Zero)
        {
            Console.Error.WriteLine("BeginUpdateResource failed: " + Marshal.GetLastWin32Error());
            return 3;
        }
        bool ok = UpdateResource(update, new IntPtr(RT_VERSION), new IntPtr(1),
            Lang, data, (uint)data.Length);
        if (!ok)
        {
            int error = Marshal.GetLastWin32Error();
            EndUpdateResource(update, true);
            Console.Error.WriteLine("UpdateResource failed: " + error);
            return 4;
        }
        if (!EndUpdateResource(update, false))
        {
            Console.Error.WriteLine("EndUpdateResource failed: " + Marshal.GetLastWin32Error());
            return 5;
        }
        Console.WriteLine("version info set: " + exeName + " " + version);
        return 0;
    }

    private static byte[] BuildVersionResource(Version version,
        Dictionary<string, string> strings)
    {
        using (MemoryStream stream = new MemoryStream())
        using (BinaryWriter writer = new BinaryWriter(stream, Encoding.Unicode, true))
        {
            long root = BeginBlock(writer, "VS_VERSION_INFO", 52, 0);
            WriteFixedFileInfo(writer, version);
            Align(writer);

            long stringFileInfo = BeginBlock(writer, "StringFileInfo", 0, 1);
            long table = BeginBlock(writer, "000004B0", 0, 1);
            foreach (KeyValuePair<string, string> pair in strings)
            {
                long item = BeginBlock(writer, pair.Key,
                    (ushort)(pair.Value.Length + 1), 1);
                WriteUtf16Z(writer, pair.Value);
                EndBlock(writer, item);
            }
            EndBlock(writer, table);
            EndBlock(writer, stringFileInfo);

            long varFileInfo = BeginBlock(writer, "VarFileInfo", 0, 1);
            long translation = BeginBlock(writer, "Translation", 4, 0);
            writer.Write(Lang);
            writer.Write(Codepage);
            EndBlock(writer, translation);
            EndBlock(writer, varFileInfo);

            EndBlock(writer, root);
            writer.Flush();
            return stream.ToArray();
        }
    }

    private static void WriteFixedFileInfo(BinaryWriter writer, Version version)
    {
        writer.Write(0xFEEF04BDu); // signature
        writer.Write(0x00010000u); // struct version
        writer.Write(MakeVersion(version.Major, version.Minor));
        writer.Write(MakeVersion(version.Build, version.Revision));
        writer.Write(MakeVersion(version.Major, version.Minor));
        writer.Write(MakeVersion(version.Build, version.Revision));
        writer.Write(0x3Fu); // file flags mask
        writer.Write(0u); // file flags
        writer.Write(0x40004u); // VOS_NT_WINDOWS32
        writer.Write(1u); // VFT_APP
        writer.Write(0u); // subtype
        writer.Write(0u); // date MS
        writer.Write(0u); // date LS
    }

    private static uint MakeVersion(int high, int low)
    {
        return ((uint)(high & 0xFFFF) << 16) | (uint)(low & 0xFFFF);
    }

    private static long BeginBlock(BinaryWriter writer, string key,
        ushort valueLength, ushort type)
    {
        long start = writer.BaseStream.Position;
        writer.Write((ushort)0); // wLength placeholder
        writer.Write(valueLength);
        writer.Write(type);
        WriteUtf16Z(writer, key);
        Align(writer);
        return start;
    }

    private static void EndBlock(BinaryWriter writer, long start)
    {
        Align(writer);
        long end = writer.BaseStream.Position;
        long length = end - start;
        if (length > ushort.MaxValue)
            throw new InvalidOperationException("version block too large");
        writer.BaseStream.Position = start;
        writer.Write((ushort)length);
        writer.BaseStream.Position = end;
    }

    private static void WriteUtf16Z(BinaryWriter writer, string value)
    {
        writer.Write(Encoding.Unicode.GetBytes(value));
        writer.Write((ushort)0);
    }

    private static void Align(BinaryWriter writer)
    {
        while ((writer.BaseStream.Position & 3) != 0)
            writer.Write((byte)0);
    }
}
