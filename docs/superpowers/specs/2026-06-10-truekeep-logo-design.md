# TrueKeep Logo 设计说明

## 方向

采用用户选定的方案 2 参考图：柔和莫兰迪绿底、暖白盾牌和大块照片光圈组合。最终资源从参考图检测绿色底边界后裁切、补齐边缘白底并缩放生成，避免外圈白边和手写几何导致的比例偏离。

## 视觉规则

- 图标主体使用参考图原始低饱和莫兰迪色，绿色底需要铺满输出画布。
- 主标记保持参考图的柔和白盾和中央光圈比例，不重新绘制。
- 不加入文字、复杂锁、相机细节或额外装饰。
- 1024 AppIcon 与应用欢迎页品牌图形使用同一张源图生成。

## 落地范围

- 从 `Tools/truekeep-logo-reference.png` 生成无外圈白边的 `AppIcon.appiconset/app-icon-1024.png`。
- 从同一源图生成无外圈白边的 `LogoMark.imageset/logo-mark.png`，并在 SwiftUI `TrueKeepLogoMark` 中直接使用图片 asset。
- 不改动业务流程、权限文案或清理逻辑。

## 验证

- 确认生成的 AppIcon 为 1024 x 1024 PNG。
- 运行 iOS 构建或测试，确认 SwiftUI 组件编译通过。
