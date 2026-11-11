param([int]$TargetProcessId)
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class WinText2 {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr lp);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint processId);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
}
"@
$results = New-Object System.Collections.Generic.List[string]
$top = [WinText2+EnumProc]{
  param($h, $l)
  $windowPid = 0
  [WinText2]::GetWindowThreadProcessId($h, [ref]$windowPid) | Out-Null
  if ($windowPid -eq $TargetProcessId -and [WinText2]::IsWindowVisible($h)) {
    $sb = New-Object System.Text.StringBuilder 1024
    [WinText2]::GetWindowTextW($h, $sb, 1024) | Out-Null
    if ($sb.Length -gt 0) { $results.Add("TOP: " + $sb.ToString()) }
    $child = [WinText2+EnumProc]{
      param($ch, $cl)
      $sb2 = New-Object System.Text.StringBuilder 2048
      [WinText2]::GetWindowTextW($ch, $sb2, 2048) | Out-Null
      if ($sb2.Length -gt 0) { $results.Add("  CHILD: " + $sb2.ToString()) }
      return $true
    }
    [WinText2]::EnumChildWindows($h, $child, [IntPtr]::Zero) | Out-Null
  }
  return $true
}
[WinText2]::EnumWindows($top, [IntPtr]::Zero) | Out-Null
$results | Select-Object -First 40
