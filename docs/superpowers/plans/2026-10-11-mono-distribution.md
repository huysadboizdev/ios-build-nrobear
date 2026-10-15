# Mono distribution — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Theo lựa chọn mới của người dùng, giữ PC Mono x64 và dựng Android Mono ARMv7; bàn giao cả hai trong `C:/Users/Admin/Downloads/filefolder/MODNROVEGETA`.

**Architecture:** Tái sử dụng bản Windows Mono đã kiểm tra, sao chép toàn bộ file và đối chiếu SHA-256. Đổi cấu hình Android và build helper sang Mono/ARMv7, dựng APK trong bản sao Unity độc lập rồi xác minh nội dung APK và chữ ký trước khi chép vào thư mục đích. Bản APK IL2CPP cũ giữ trong thư mục phát hành trước đó, không được đưa vào MODNROVEGETA.

**Tech Stack:** Unity 2022.3.62f2, Mono, Windows x64, Android ARMv7, aapt/apksigner.

- [x] Sao chép PC đầy đủ vào MODNROVEGETA, đối chiếu SHA-256 132 file và kiểm tra Managed DLL/MonoBleedingEdge.
- [x] Cấu hình `Assets/Editor/ClientDistributionBuild.cs`: Android dùng `ScriptingImplementation.Mono2x`, kiến trúc `AndroidArchitecture.ARMv7`; thêm Backend/Architectures vào báo cáo.
- [x] Đồng bộ `ProjectSettings/ProjectSettings.asset`: Android backend Mono và kiến trúc ARMv7; giữ IP VPS, icon, hiệu ứng, hai scene và chế độ ngang.
- [x] Dựng APK ở `Builds/Distribution/20261011-MonoARMv7/Android/NRO.apk`, chạy bộ kiểm tra Unity đã có trước build.
- [x] Kiểm tra APK có ARMv7/Mono/Managed DLL, không có ARM64/libil2cpp; kiểm tra landscape, quyền mạng, package, icon và chữ ký.
- [x] Chép APK cùng metadata vào MODNROVEGETA và đối chiếu SHA-256.

Người dùng đã chọn rõ PC và Android đều Mono, Android chỉ ARMv7. WebGL giữ backend bắt buộc của nền tảng, không thuộc yêu cầu chuyển Mono này. APK không được xác nhận trên điện thoại thật trong phiên này.

## Kết quả

Android Mono build Succeeded, 0 lỗi, 82 cảnh báo; 202 kiểm tra hào quang, giải mã NPC và 169.584 kiểm tra kỹ năng đạt trước build. APK 83.886.776 bytes, SHA-256 `906cb58583d185bae5ec2a0797c19a7d3ab500dea335b95fed933868d4bdf312`. Archive có `lib/armeabi-v7a/libmono-native.so`, `libmonobdwgc-2.0.so` và `assets/bin/Data/Managed/Assembly-CSharp.dll`; không có libil2cpp hoặc ARM64. Chữ ký APK v1/v2 được xác minh.
