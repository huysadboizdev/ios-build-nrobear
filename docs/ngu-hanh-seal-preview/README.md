# Sửa hình phong ấn Ngộ Không

Ảnh chân dung4520 lớn55×52px ởzoom1 khiến đầu NPC phóng to; đá chữ nhật92px cũng không hợp cảnh. Hai tab Game1/Game2 đã đổi sang sprite đầu4468 19×19px và ảnh đá11 49×37px, bùa6×18px. Ảnh đá được chép nguyên bản từ server đủ4zoom, không sửa tài nguyên gốc. Kích thước tên NPC `ch=38` theo khối đá mới.

`seal-preview.png` là hình kiểm tra được dựng từ lệnh vẽ thu trực tiếp khi chạy method C# thực, dùng tài nguyênzoom4; không phải ảnh chụp gameplay. Hai file draw-commands ghi lệnh của từng tab. Kiểm thử compile/chạy renderer xác nhận sprite đúng, không có khối chữ nhật lớn và ảnh đá chỉ nạp một lần. Toàn bộ scriptUnity đã biên dịch thành công trong project riêng; kiểm tra resourceUnity xác minh đường dẫn/nativezoom/kích thước.

Trong Unity đang Play: Stop → chờ import/compile → Play lại để thấy bản sửa. Sourceclient và resource đã cập nhật; EXE cũ cần build lại. Không đổi SQL hoặc JAR server trong lần sửa hiển thị này.
