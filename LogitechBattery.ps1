# Icono en la bandeja del sistema con la bateria (%) de un raton y un teclado Logitech
# conectados por Bluetooth. Lee la bateria por HID++ 2.0 (funciones 0x1004 / 0x1000).

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public class BatteryInfo { public string Kind; public int Percent; public bool Charging; }

public static class LogiBattery {
    const ushort Vendor = 0x046D;

    [StructLayout(LayoutKind.Sequential)] struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid InterfaceClassGuid; public int Flags; public IntPtr Reserved; }
    [StructLayout(LayoutKind.Sequential)] struct HIDD_ATTRIBUTES { public int Size; public ushort VendorID, ProductID, VersionNumber; }
    [StructLayout(LayoutKind.Sequential)] struct HIDP_CAPS { public ushort Usage, UsagePage, InputReportByteLength, OutputReportByteLength, FeatureReportByteLength; [MarshalAs(UnmanagedType.ByValArray, SizeConst=17)] public ushort[] Reserved; public ushort a,b,c,d,e,f,g,h,i,j,k; }
    [StructLayout(LayoutKind.Sequential)] struct OVERLAPPED { public IntPtr Internal, InternalHigh; public uint Offset, OffsetHigh; public IntPtr hEvent; }

    [DllImport("hid.dll")] static extern void HidD_GetHidGuid(out Guid g);
    [DllImport("hid.dll")] static extern bool HidD_GetAttributes(IntPtr h, ref HIDD_ATTRIBUTES a);
    [DllImport("hid.dll")] static extern bool HidD_GetPreparsedData(IntPtr h, out IntPtr p);
    [DllImport("hid.dll")] static extern bool HidD_FreePreparsedData(IntPtr p);
    [DllImport("hid.dll")] static extern int HidP_GetCaps(IntPtr p, ref HIDP_CAPS c);
    [DllImport("setupapi.dll")] static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr p, int flags);
    [DllImport("setupapi.dll")] static extern bool SetupDiEnumDeviceInterfaces(IntPtr s, IntPtr d, ref Guid g, int i, ref SP_DEVICE_INTERFACE_DATA data);
    [DllImport("setupapi.dll", CharSet=CharSet.Unicode)] static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr s, ref SP_DEVICE_INTERFACE_DATA data, IntPtr detail, int size, out int req, IntPtr di);
    [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr s);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFile(string n, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr t);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool ReadFile(IntPtr h, IntPtr buf, uint n, IntPtr read, ref OVERLAPPED ov);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool WriteFile(IntPtr h, IntPtr buf, uint n, IntPtr written, ref OVERLAPPED ov);
    [DllImport("kernel32.dll", SetLastError=true)] static extern IntPtr CreateEvent(IntPtr attr, bool manual, bool initial, string name);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetOverlappedResult(IntPtr h, ref OVERLAPPED ov, out uint n, bool wait);
    [DllImport("kernel32.dll")] static extern bool CancelIoEx(IntPtr h, ref OVERLAPPED ov);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

    static readonly IntPtr Invalid = new IntPtr(-1);

    class Group { public string Kind; public string HidppPath; }

    // Agrupa las colecciones HID de cada dispositivo Logitech: tipo (raton/teclado) y canal HID++
    static Dictionary<string, Group> Enumerate() {
        var groups = new Dictionary<string, Group>();
        Guid g; HidD_GetHidGuid(out g);
        IntPtr set = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, 0x12);
        for (int i = 0; ; i++) {
            var d = new SP_DEVICE_INTERFACE_DATA(); d.cbSize = Marshal.SizeOf(d);
            if (!SetupDiEnumDeviceInterfaces(set, IntPtr.Zero, ref g, i, ref d)) break;
            int req; SetupDiGetDeviceInterfaceDetail(set, ref d, IntPtr.Zero, 0, out req, IntPtr.Zero);
            IntPtr buf = Marshal.AllocHGlobal(req);
            Marshal.WriteInt32(buf, IntPtr.Size == 8 ? 8 : 6);
            if (SetupDiGetDeviceInterfaceDetail(set, ref d, buf, req, out req, IntPtr.Zero)) {
                string path = Marshal.PtrToStringUni(new IntPtr(buf.ToInt64() + 4));
                int col = path.IndexOf("&col");
                IntPtr h = col < 0 ? Invalid : CreateFile(path, 0, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
                if (h != Invalid) {
                    var a = new HIDD_ATTRIBUTES(); a.Size = Marshal.SizeOf(a);
                    IntPtr pp;
                    if (HidD_GetAttributes(h, ref a) && a.VendorID == Vendor && HidD_GetPreparsedData(h, out pp)) {
                        var c = new HIDP_CAPS(); HidP_GetCaps(pp, ref c);
                        HidD_FreePreparsedData(pp);
                        string stem = path.Substring(0, col);
                        Group grp;
                        if (!groups.TryGetValue(stem, out grp)) { grp = new Group(); groups[stem] = grp; }
                        if (c.UsagePage == 1 && c.Usage == 2) grp.Kind = "mouse";
                        else if (c.UsagePage == 1 && c.Usage == 6) grp.Kind = "keyboard";
                        else if (c.UsagePage == 0xFF43 && c.Usage == 0x0202) grp.HidppPath = path;
                    }
                    CloseHandle(h);
                }
            }
            Marshal.FreeHGlobal(buf);
        }
        SetupDiDestroyDeviceInfoList(set);
        return groups;
    }

    // E/S solapada con tiempo maximo, para no quedarse bloqueado si el dispositivo duerme
    static bool Io(IntPtr h, byte[] data, bool write, int ms) {
        IntPtr buf = Marshal.AllocHGlobal(20);
        IntPtr ev = CreateEvent(IntPtr.Zero, true, false, null);
        var ov = new OVERLAPPED(); ov.hEvent = ev;
        try {
            if (write) Marshal.Copy(data, 0, buf, 20);
            bool ok = write ? WriteFile(h, buf, 20, IntPtr.Zero, ref ov) : ReadFile(h, buf, 20, IntPtr.Zero, ref ov);
            if (!ok) {
                if (Marshal.GetLastWin32Error() != 997) return false;
                if (WaitForSingleObject(ev, (uint)ms) != 0) {
                    CancelIoEx(h, ref ov);
                    uint dummy; GetOverlappedResult(h, ref ov, out dummy, true);
                    return false;
                }
            }
            uint n;
            if (!GetOverlappedResult(h, ref ov, out n, false) || n == 0) return false;
            if (!write) Marshal.Copy(buf, data, 0, 20);
            return true;
        } finally { Marshal.FreeHGlobal(buf); CloseHandle(ev); }
    }

    // Peticion HID++ 2.0 (mensaje largo, dispositivo 0xFF = conexion directa) y espera de su respuesta
    static byte[] Call(IntPtr h, byte feature, int func, byte[] p, int timeoutMs) {
        var req = new byte[20];
        req[0] = 0x11; req[1] = 0xFF; req[2] = feature; req[3] = (byte)((func << 4) | 0x07);
        if (p != null) Array.Copy(p, 0, req, 4, p.Length);
        if (!Io(h, req, true, timeoutMs)) return null;
        var end = DateTime.UtcNow.AddMilliseconds(timeoutMs);
        while (DateTime.UtcNow < end) {
            var r = new byte[20];
            if (!Io(h, r, false, (int)Math.Max(50, (end - DateTime.UtcNow).TotalMilliseconds))) return null;
            if (r[2] == 0xFF) return null;
            if (r[2] == feature && (r[3] >> 4) == func && (r[3] & 0x0F) == 0x07) return r;
        }
        return null;
    }

    static int FeatureIndex(IntPtr h, int id) {
        var r = Call(h, 0x00, 0, new byte[] { (byte)(id >> 8), (byte)(id & 0xFF) }, 1500);
        return r == null ? 0 : r[4];
    }

    static BatteryInfo ReadBattery(string kind, string path) {
        IntPtr h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero); // lectura/escritura, solapado
        if (h == Invalid) return null;
        try {
            // 0x1004 Unified Battery: porcentaje exacto. 0x1000 Battery Level Status: porcentaje por niveles.
            int idx = FeatureIndex(h, 0x1004);
            int func = 1;
            if (idx == 0) { idx = FeatureIndex(h, 0x1000); func = 0; }
            if (idx == 0) return null;
            var r = Call(h, (byte)idx, func, null, 1500);
            if (r == null) return null;
            int status = r[6];
            return new BatteryInfo { Kind = kind, Percent = Math.Min(100, (int)r[4]), Charging = status == 1 || status == 2 || status == 4 };
        } finally { CloseHandle(h); }
    }

    public static List<BatteryInfo> ReadAll() {
        var res = new List<BatteryInfo>();
        foreach (var grp in Enumerate().Values) {
            if (grp.Kind == null || grp.HidppPath == null) continue;
            var b = ReadBattery(grp.Kind, grp.HidppPath);
            if (b != null) res.Add(b);
        }
        return res;
    }
}
"@

$RefreshMinutes = 5
$LowBattery = 20

function New-RoundRect($x, $y, $w, $h, $r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $p
}

function Test-LightTheme {
    try { (Get-ItemPropertyValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name SystemUsesLightTheme) -eq 1 }
    catch { $false }
}

# Icono de 64x64: simbolo (raton o teclado) arriba y el porcentaje debajo, en verde o rojo
function New-BatteryBitmap($kind, $percent) {
    $light = Test-LightTheme
    $symbol = if ($light) { [System.Drawing.Color]::FromArgb(32, 32, 32) } else { [System.Drawing.Color]::White }
    if ($null -eq $percent) { $color = [System.Drawing.Color]::Gray; $text = '--' }
    else {
        $text = "$percent"
        if ($percent -lt $LowBattery) { $color = if ($light) { [System.Drawing.Color]::FromArgb(214, 40, 40) } else { [System.Drawing.Color]::FromArgb(255, 70, 70) } }
        else { $color = if ($light) { [System.Drawing.Color]::FromArgb(0, 140, 60) } else { [System.Drawing.Color]::FromArgb(60, 220, 100) } }
    }

    $bmp = New-Object System.Drawing.Bitmap 64, 64, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAlias'

    $pen = New-Object System.Drawing.Pen $symbol, 3
    $brush = New-Object System.Drawing.SolidBrush $symbol
    if ($kind -eq 'mouse') {
        $body = New-RoundRect 23 1 18 24 9
        $g.DrawPath($pen, $body)
        $g.DrawLine($pen, 32, 2, 32, 12)
        $g.DrawLine($pen, 23, 12, 41, 12)
        $body.Dispose()
    } else {
        $body = New-RoundRect 12 4 40 19 3
        $g.DrawPath($pen, $body)
        foreach ($x in 18, 26, 34, 42) { $g.FillRectangle($brush, $x, 9, 5, 3) }
        $g.FillRectangle($brush, 21, 15, 22, 3)
        $body.Dispose()
    }

    $fmt = [System.Drawing.StringFormat]::GenericTypographic
    $size = 42
    do {
        $font = New-Object System.Drawing.Font 'Segoe UI', $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $m = $g.MeasureString($text, $font, 200, $fmt)
        if ($m.Width -le 64) { break }
        $font.Dispose(); $size -= 2
    } while ($size -gt 10)
    $tb = New-Object System.Drawing.SolidBrush $color
    $g.DrawString($text, $font, $tb, (64 - $m.Width) / 2, 26 + (38 - $m.Height) / 2, $fmt)

    $font.Dispose(); $tb.Dispose(); $pen.Dispose(); $brush.Dispose(); $g.Dispose()
    $bmp
}

Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool DestroyIcon(IntPtr h);' -Name Win32 -Namespace Tray

function ConvertTo-TrayIcon($bmp) {
    $h = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($h).Clone()
    [Tray.Win32]::DestroyIcon($h) | Out-Null
    $bmp.Dispose()
    $icon
}

function Start-BatteryTray {
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Local\LogitechBatteryTray', [ref]$created)
    if (-not $created) { return }

    $names = @{ mouse = "Rat$([char]0xF3)n"; keyboard = 'Teclado' }
    $state = @{}
    $tray = @{}

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $refreshItem = $menu.Items.Add('Actualizar')
    $exitItem = $menu.Items.Add('Salir')

    foreach ($kind in 'mouse', 'keyboard') {
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.ContextMenuStrip = $menu
        $n.Icon = ConvertTo-TrayIcon (New-BatteryBitmap $kind $null)
        $tray[$kind] = $n
    }

    $update = {
        try {
            foreach ($b in [LogiBattery]::ReadAll()) { $state[$b.Kind] = $b }
        } catch { }
        foreach ($kind in 'mouse', 'keyboard') {
            if (-not $state.ContainsKey($kind)) { continue }
            $b = $state[$kind]
            $n = $tray[$kind]
            $old = $n.Icon
            $n.Icon = ConvertTo-TrayIcon (New-BatteryBitmap $kind $b.Percent)
            if ($old) { $old.Dispose() }
            $n.Text = "$($names[$kind]): $($b.Percent) %" + $(if ($b.Charging) { ' (cargando)' } else { '' })
            $n.Visible = $true
        }
    }

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = $RefreshMinutes * 60 * 1000
    $timer.Add_Tick($update)
    $refreshItem.Add_Click($update)
    $exitItem.Add_Click({
        $timer.Stop()
        foreach ($n in $tray.Values) { $n.Visible = $false; $n.Dispose() }
        [System.Windows.Forms.Application]::Exit()
    })

    & $update
    $timer.Start()
    [System.Windows.Forms.Application]::Run()
    $mutex.ReleaseMutex()
}

# Con "dot-sourcing" (. .\LogitechBattery.ps1) solo se cargan las funciones
if ($MyInvocation.InvocationName -ne '.') { Start-BatteryTray }
