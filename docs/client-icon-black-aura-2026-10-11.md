# Client PC, Android và web: icon và hào quang đen

Icon ứng dụng lấy nguyên ảnh `iconlogo.png` của project `PRJ 3in1 Goc`, Vegeta tóc tím. Hào quang đen sử dụng 7 khung hình của project này và bắt đầu ở **70.000.000.000 sức mạnh**, dùng tùy chọn **Hào quang sức mạnh** đang có. Áp dụng độc lập cho hai tài khoản.

Nhân vật mình và đệ tử có số liệu sức mạnh thật được kiểm tra đúng mốc. Người chơi khác giữ hiệu ứng hiện có vì giao thức hiện tại chỉ gửi cấp, không gửi sức mạnh đầy đủ. Các trạng thái di chuyển, nhảy và đánh vẫn giữ hiệu ứng; chết/ẩn, biến khỉ, bản sao, mini pet, cấu hình thấp và tắt hiệu ứng sẽ không vẽ đen.

Đã sửa lớp phía sau của hào quang đặc biệt bị đảo điều kiện bật/tắt. Khi đăng xuất, dữ liệu đệ tử được xóa để tài khoản sau không nhận nhầm sức mạnh tài khoản trước. Ảnh được cache riêng theo zoom/tài khoản; giữ texture Resources dùng chung, giải phóng bản co ảnh khi đổi zoom, và quay về hiệu ứng cũ nếu ảnh thiếu.

Source native: `Assets/Scripts/Assembly-CSharp/Game1/BlackPowerAura.cs`, namespace Game2 tương ứng và các điểm vẽ trong `Char.cs`. Build bằng `Assets/Editor/ClientDistributionBuild.cs`; cấu hình icon bằng `Assets/Editor/ClientBranding.cs`.

Source web tương ứng: `C:/Users/Admin/Downloads/nroteam/Teamobi2026/ClientWeb/PRJ_2Tab_Web`. Bộ script rời `C:/Users/Admin/Downloads/Scriptsweb/Scripts` cũng được cập nhật, kèm hướng dẫn đặt resource; đây không phải project Unity đầy đủ để build độc lập.

Kiểm tra hồi quy trong Unity bao gồm 202 kiểm tra hào quang cho hai tài khoản: biên 70 tỉ, trạng thái, tùy chọn, quyền sở hữu đệ tử, đăng xuất, cả 7 ảnh ở zoom 1–4, cache dùng lại, thiếu ảnh và phục hồi khi đổi zoom. Bộ kiểm tra NPC và kỹ năng tốc độ cao chạy trước mỗi build. Log và BuildReport là bằng chứng build; các cảnh báo biên dịch cũ được giữ nguyên.

Bản phát hành đặt tại `Builds/Distribution/20261011-Icon70B`. Windows cần toàn bộ thư mục cùng EXE, được đóng ZIP. APK Android có ARMv7 và ARM64, màn hình ngang. IP native giữ `160.191.245.239:14445`; kết nối TCP đến VPS đã được kiểm tra. Việc đăng nhập tài khoản thật và cài APK trên Android thật cần kiểm tra thực tế; chưa có bằng chứng kiểm thử trên thiết bị Android thật trong lần dựng này.

Project hiện chưa cấu hình keystore phát hành riêng; trạng thái ký được ghi trong `Android/signing.txt`. Khi phát hành các bản cập nhật ứng dụng, cần giữ ổn định khóa ký. Không có thay đổi server/JAR hoặc giao thức cho tính năng này.
