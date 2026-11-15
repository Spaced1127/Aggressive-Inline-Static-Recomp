from pathlib import Path
import difflib

root = Path(r"H:\Projects\Agressive Inline Static Recompile")
base = (root / "work" / "CoreDevice.cpp.orig").read_text(encoding="utf-8")
base = base.replace("\r\n", "\n")

old_include = "#include <algorithm>\n#include <cmath>\n#include <memory>"
new_include = "#include <algorithm>\n#include <cmath>\n#include <cstdio>\n#include <memory>"
assert old_include in base
modified = base.replace(old_include, new_include, 1)

old = """std::shared_ptr<Device> DeviceContainer::FindDevice(const DeviceQualifier& devq) const
{
  std::lock_guard lk(m_devices_mutex);
  for (const auto& d : m_devices)
  {
    if (devq == d.get())
      return d;
  }

  return nullptr;
}
"""

new = """std::shared_ptr<Device> DeviceContainer::FindDevice(const DeviceQualifier& devq) const
{
  std::lock_guard lk(m_devices_mutex);
  for (const auto& d : m_devices)
  {
    if (devq == d.get())
      return d;
  }

  // ModernGekko: a profile written for one pad must still bind another SDL
  // pad. RecompLauncher never opens the controller page, so a DualSense
  // profile would otherwise leave an Xbox/PlayStation/Switch pad dead.
  if (devq.source == "SDL")
  {
    for (const auto& d : m_devices)
    {
      if (d->GetSource() != "SDL")
        continue;
      const std::string name = d->GetName();
      if (name.empty() || name.find("Keyboard") != std::string::npos ||
          name.find("Mouse") != std::string::npos)
        continue;
      static bool logged_fallback = false;
      if (!logged_fallback)
      {
        logged_fallback = true;
        std::fprintf(stderr,
                     "controller: configured device '%s' not found; using '%s'\\n",
                     devq.ToString().c_str(), name.c_str());
      }
      return d;
    }
  }

  return nullptr;
}
"""

assert old in modified, "old function not found"
modified = modified.replace(old, new, 1)

a = "a/Source/Core/InputCommon/ControllerInterface/CoreDevice.cpp"
b = "b/Source/Core/InputCommon/ControllerInterface/CoreDevice.cpp"
diff = difflib.unified_diff(base.splitlines(True), modified.splitlines(True),
                            fromfile=a, tofile=b)
output = root / "docs" / "patches" / "dolphin-sdl-controller-fallback.patch"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("".join(diff), encoding="utf-8")
print("wrote", output)
print("".join(diff).splitlines()[0:12])
