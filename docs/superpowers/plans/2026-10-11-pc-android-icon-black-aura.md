# PC/Android: icon 3 in 1 và hào quang đen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dùng icon từ project 3 in 1, bổ sung hào quang đen từ đúng 70 tỉ sức mạnh và xuất client Windows cùng APK Android từ PRJ_2Tab_550K sau khi người dùng duyệt kế hoạch.

**Architecture:** Lấy ảnh gốc và bộ 7 khung hình từ project tham chiếu; tích hợp riêng vào hai namespace Game1/Game2. Dùng sức mạnh kiểu long để kiểm tra mốc, giữ tùy chọn Hào quang sức mạnh đang có, tải ảnh qua loadImageResize và cache theo mức zoom. Build ở bản sao độc lập để không tranh chấp project Unity người dùng đang mở.

**Tech Stack:** Unity 2022.3.62f2, C#, Windows x64/Mono, Android IL2CPP ARMv7 + ARM64, SDK/NDK/OpenJDK đi kèm Unity.

## Dữ kiện đã kiểm tra và phạm vi cần duyệt

- Project tham chiếu: `C:/Users/Admin/Downloads/filefolder/PRJ 3in1 Goc/PRJ 3in1 Goc`.
- Icon đúng theo PlayerSettings của project tham chiếu: `Assets/Resources/iconlogo.png`, Vegeta tóc tím, 549 × 549, GUID `3b18bfed5de12374882b731617e95bb6`.
- Icon hiện tại của PRJ_2Tab_550K đang trỏ đến GUID không có asset tương ứng. Phải sửa cấu hình, không chỉ chép ảnh.
- Hiệu ứng tham chiếu: `Assets/Resources/res/x4/poweraura/black/0.png` đến `6.png`. Bộ đọc ảnh của client đích đã có khả năng co ảnh x4 theo zoom.
- Bản 3 in 1 chọn đen ở `clevel >= 17`. Server hiện trả cấp 17 từ **70.010.000.000**, nên chép nguyên điều kiện sẽ sai yêu cầu 70 tỉ.
- Địa chỉ người dùng đã cấu hình trong `Management.cs`: `160.191.245.239:14445`; giữ cấu hình này khi dựng bản phát hành.
- Phạm vi mặc định: mốc chính xác **70.000.000.000** cho nhân vật đang điều khiển và đệ tử khi client có sức mạnh thực tế; cả hai tài khoản.
- Client chỉ nhận cấp của người chơi khác trong `Controller.readCharInfo`, không nhận sức mạnh đầy đủ. Không suy diễn mốc 70 tỉ từ cấp. Hiệu ứng của người chơi khác giữ xử lý hiện có trong phạm vi này. Nếu người dùng muốn mọi người nhìn thấy hào quang đen của nhau chính xác từ 70 tỉ, cần duyệt thêm phần server/protocol trước khi triển khai.
- Không thêm dòng cấu hình mới: hào quang đen dùng nút **Hào quang sức mạnh** hiện có. Không đưa bộ xanh/tím của 3 in 1 vào phạm vi này.
- Người dùng đã duyệt triển khai và bổ sung đồng bộ project WebGL cùng thư mục Scriptsweb/Scripts. Source và các bản dựng PC/Android/WebGL đã cập nhật; kết quả kiểm chứng được ghi ở cuối kế hoạch.

## Task 1: Icon ứng dụng

**Files:**
- Copy nguồn tham chiếu `Assets/Resources/iconlogo.png` → `Assets/Branding/iconlogo.png` của PRJ_2Tab_550K.
- Create: `Assets/Branding/iconlogo.png.meta` thông qua Unity import.
- Modify: `ProjectSettings/ProjectSettings.asset` thông qua PlayerSettings.

- [ ] Chép đúng ảnh có GUID được xác minh ở trên, đối chiếu SHA-256 ảnh nguồn và đích.
- [ ] Import bằng Unity; lấy Texture2D từ `Assets/Branding/iconlogo.png`.
- [ ] Gán icon mặc định và icon Windows; thay các slot Android còn trỏ GUID cũ. Kiểm tra icon Legacy, Round và Adaptive mà phiên bản Unity cung cấp; sử dụng cùng ảnh gốc, xem preview mặt nạ để tránh cắt mặt nhân vật.
- [ ] Kiểm tra mọi GUID icon được gán đều có asset thật; xem preview icon PC và Android trước khi build.

## Task 2: Ngưỡng và bộ ảnh hào quang cho hai tài khoản

**Files:**
- Create: `Assets/Scripts/Assembly-CSharp/Game1/BlackPowerAura.cs`.
- Create: `Assets/Scripts/Assembly-CSharp/Game2/BlackPowerAura.cs`.
- Copy: `Assets/Resources/res/x4/poweraura/black/0.png` … `6.png` và import metadata mới.
- Create: `Assets/Editor/BlackPowerAuraRegression.cs`.

- [ ] Viết kiểm tra ngưỡng cho cả Game1 và Game2 trước khi nối vào phần vẽ:

```csharp
using System;
public static class BlackPowerAuraRegression
{
    public static void Run()
    {
        long[] powers = { 69999999999L, 70000000000L, 70000000001L, 100000000000L };
        bool[] expected = { false, true, true, true };
        for (int i = 0; i < powers.Length; i++)
        {
            if (Game1.BlackPowerAura.ReachesThreshold(powers[i]) != expected[i]
                || Game2.BlackPowerAura.ReachesThreshold(powers[i]) != expected[i])
                throw new Exception("Black aura threshold mismatch: " + powers[i]);
        }
        UnityEngine.Debug.Log("BLACK_POWER_AURA_THRESHOLD_PASS");
    }
}
```

- [ ] Chạy kiểm tra khi chưa có helper: phải thất bại do thiếu kiểu BlackPowerAura; sau đó tạo helper trong mỗi namespace tương ứng:

```csharp
public static bool ReachesThreshold(long power)
{
    return power >= 70000000000L;
}
```

- [ ] Chép 7 ảnh đen gốc. Tải chúng bằng `GameCanvas.loadImageResize("/poweraura/black/" + i + ".png")`; không dùng loadImage theo zoom vì nguồn chỉ có x4.
- [ ] Cache riêng cho Game1/Game2, với `Image[7]` và zoom đã tải. Chỉ thay cache sau khi cả 7 ảnh tải thành công; giải phóng cache cũ khi zoom đổi. Khi thiếu ảnh, trở về hiệu ứng hiện có, không lặp tải trong mỗi frame.
- [ ] Chọn khung hình như bản tham chiếu: `(GameCanvas.gameTick / 3 + (character.charID & int.MaxValue) % 7) % 7`; vẽ tại `(character.cx, character.cy + 4)` với `BOTTOM | HCENTER`.
- [ ] Chạy kiểm tra ngưỡng qua Unity batchmode `-executeMethod BlackPowerAuraRegression.Run`; kết quả phải có `BLACK_POWER_AURA_THRESHOLD_PASS` và không có lỗi biên dịch.

## Task 3: Tích hợp vẽ, trạng thái và tùy chọn

**Files:**
- Modify: `Assets/Scripts/Assembly-CSharp/Game1/Char.cs`, `paintSuperEffBehind` và `paintSuperEffFront`.
- Modify: `Assets/Scripts/Assembly-CSharp/Game2/Char.cs`, hai phương thức tương ứng.
- Modify: hai helper `BlackPowerAura.cs` đã tạo ở Task 2.

- [ ] Chỉ chọn đen khi biết sức mạnh của nhân vật: dùng đối tượng nhân vật mình hoặc đối tượng đệ tử có số liệu thực tế; không dùng mặc định cPower=0 của người chơi khác.
- [ ] Điều kiện vẽ giữ công tắc `Char.isPaintAura2`, kiểm tra cấu hình thấp, giảm dung lượng, panel đang mở, trạng thái chết/ẩn, bản sao, mini pet và biến khỉ. Ưu tiên hào quang đặc biệt đang được bật để không chồng hai hiệu ứng.
- [ ] Nối lớp vẽ đen vào phía sau nhân vật; khi đen đã vẽ, bỏ lớp hào quang sức mạnh cũ ở cả phía sau và phía trước. Nếu ảnh chưa sẵn sàng, tiếp tục lớp cũ.
- [ ] Kiểm tra tại ba giá trị 69.999.999.999 / 70.000.000.000 / 70.000.000.001: dưới mốc giữ cũ, đúng và trên mốc hiện đen.
- [ ] Kiểm tra bật/tắt Hào quang sức mạnh, cấu hình thấp, chết/hồi sinh, đổi map, đăng nhập lại, zoom 1/2/3/4 và đổi hai tài khoản. Không được tải texture mỗi frame hoặc xuất hiện hai lớp hào quang đồng thời.
- [ ] Chạy kiểm tra hồi quy NPC và kỹ năng tốc độ cao đang có; không bỏ qua các lỗi compile của namespace tài khoản thứ hai.

## Task 4: Build và bàn giao

**Files:**
- Create/update build entry trong bản sao độc lập: `Assets/Editor/ClientDistributionBuild.cs`.
- Output: `Builds/Distribution/<timestamp>/Windows/NRO.exe` cùng toàn bộ thư mục phụ trợ.
- Output: `Builds/Distribution/<timestamp>/Android/NRO.apk`.
- Output: thư mục Windows nén ZIP, thông tin phiên bản và SHA-256.

- [ ] Đồng bộ source đã duyệt và IP hiện tại sang bản sao độc lập; giữ scene `Assets/Scenes/NROL.unity` và `Assets/Scenes/NROL1.unity` trong Scenes In Build.
- [ ] Build Windows x64 bản phát hành, không bật Development Build. Đọc BuildReport; yêu cầu Succeeded và không có compile error.
- [ ] Build APK Android với IL2CPP, ARMv7 + ARM64, ngang màn hình; kiểm tra SDK/NDK/OpenJDK đi kèm Unity trước khi chạy. Dùng ký phát hành hiện có nếu có; nếu chưa có keystore phát hành, ghi rõ APK dùng khóa phát triển và cần khóa cố định để cập nhật ứng dụng sau này.
- [ ] Xác minh EXE có icon mới; APK có icon và manifest đúng, đủ native library cho các kiến trúc đã chọn, package/version và quyền mạng.
- [ ] Chạy PC: đăng nhập đúng VPS, đổi tài khoản, kiểm tra NPC và hào quang. APK cần cài thử trên Android thật để xác nhận điều khiển chạm, icon launcher và hiệu ứng; nếu chưa có thiết bị, ghi rõ giới hạn này khi bàn giao.
- [ ] Nén toàn bộ thư mục Windows để người dùng có thể chạy được; không bàn giao riêng EXE. Xuất SHA-256 của ZIP/APK và đường dẫn file.

## Tiêu chí duyệt kế hoạch

1. Icon Vegeta tóc tím từ đúng PlayerSettings của 3 in 1.
2. Hào quang đen từ **70 tỉ sức mạnh**, hai tài khoản, sử dụng tùy chọn đang có.
3. Phạm vi sức mạnh chính xác của nhân vật mình/đệ tử; đồng bộ hiển thị của người chơi khác là phần server bổ sung nếu được yêu cầu.
4. Bàn giao Windows đầy đủ và APK Android; build sau khi người dùng duyệt.

## Kết quả triển khai

- Icon PC đã kiểm tra bằng ảnh trích từ EXE; icon Android đã kiểm tra bằng resource trích từ APK và XML adaptive icon.
- Unity: 202 kiểm tra hào quang, giải mã ảnh NPC và 169.584 kiểm tra kỹ năng đạt. Các lỗi điều kiện hào quang phía sau và dữ liệu đệ tử sau đăng xuất đã có kiểm tra thất bại trước sửa và đạt sau sửa.
- Windows x64: build thành công, 0 lỗi, 64 cảnh báo. ZIP đầy đủ: `Builds/Distribution/20261011-Icon70B/NRO-Windows-x64.zip`.
- Android: build thành công, 0 lỗi, 82 cảnh báo. APK: `Builds/Distribution/20261011-Icon70B/Android/NRO.apk`; xác minh chữ ký, package, SDK 22/34, quyền mạng, ARMv7/ARM64 và manifest landscape.
- WebGL mới đã phục vụ tại localhost:8086: 0 lỗi build, 68 cảnh báo; 202 kiểm tra Unity và 17 kiểm tra Node đạt. Trình duyệt Chromium mô phỏng 5 nhóm thiết bị đã chạy hai tài khoản/đổi kích thước/xoay màn hình, không có lỗi runtime. Cấu hình kết nối web giữ nguyên và có backup build cũ.
- Scriptsweb/Scripts đã đồng bộ helper, điểm vẽ, xóa dữ liệu đệ tử, giải phóng RenderTexture, icon và 7 ảnh; 3 bộ kiểm tra source rời đạt.
- APK dùng khóa ký phát triển của Unity. Chưa cài thử trên Android thật hoặc xác minh gameplay bằng tài khoản thật trong lần dựng này.
- Thông tin SHA-256 và kiểm tra APK đặt cùng thư mục bản phát hành. Không thay server/JAR/giao thức.
