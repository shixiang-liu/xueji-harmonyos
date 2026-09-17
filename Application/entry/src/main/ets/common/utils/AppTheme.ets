// ============================================================================
// 主题系统 - Creamy UI 风格 (Soft, Clean, Friendly)
// ============================================================================
// 设计哲学：奶油感、柔光、悬浮卡片、空气层次
// 配色：低饱和 + 奶油白 (#F7F5F2)
// 阴影：空气悬浮感 (0px 10px 25px rgba(0,0,0,0.05))
// 圆角：大圆角 (24vp-38vp)
// ============================================================================

// 简易主题管理器：集中记录当前深浅色状态
export class AppThemeManager {
  private static _isDark: boolean = false
  static setIsDarkMode(isDark: boolean) {
    AppThemeManager._isDark = isDark
  }
  static isDarkMode(): boolean {
    return AppThemeManager._isDark
  }
}

// ============================================================================
// 颜色系统 - Creamy Palette（支持深浅色切换）
// ============================================================================
export class AppColors {
  // 主色调 - Warm Coral（DESIGN.md primary）
  static readonly ACCENT: string = '#cc785c'
  static readonly ACCENT_BG: string = 'rgba(204, 120, 92, 0.1)'

  // 警示色 - 活力橙
  static readonly WARNING: string = '#FF8533' // 稍微调柔一点
  static readonly WARNING_BG: string = 'rgba(255, 133, 51, 0.1)'

  // 成功色
  static readonly SUCCESS: string = '#34D399' // 更加清新的绿
  static readonly SUCCESS_BG: string = 'rgba(52, 211, 153, 0.1)'

  // 错误色
  static readonly ERROR: string = '#F87171' // 柔和红
  static readonly ERROR_BG: string = 'rgba(248, 113, 113, 0.1)'

  // 信息色
  static readonly INFO: string = '#60A5FA'
  static readonly INFO_BG: string = 'rgba(96, 165, 250, 0.1)'

  // 品牌色
  static readonly BRAND_AMBER: string = '#FBBF24'

  // 文字色阶 - 柔和深灰（动态）
  private static readonly TEXT_PRIMARY_LIGHT: string = '#1C1917'
  private static readonly TEXT_SECONDARY_LIGHT: string = '#57534E'
  private static readonly TEXT_TERTIARY_LIGHT: string = '#A8A29E'
  private static readonly TEXT_HINT_LIGHT: string = '#D6D3D1'
  private static readonly TEXT_DISABLED_LIGHT: string = '#E7E5E4'
  static readonly TEXT_WHITE: string = '#FFFFFF'        // 纯白
  static readonly TEXT_LINK: string = '#cc785c'         // 链接色

  static get TEXT_PRIMARY(): string { return AppThemeManager.isDarkMode() ? AppColors.TEXT_DARK_PRIMARY : AppColors.TEXT_PRIMARY_LIGHT }
  static get TEXT_SECONDARY(): string { return AppThemeManager.isDarkMode() ? AppColors.TEXT_DARK_SECONDARY : AppColors.TEXT_SECONDARY_LIGHT }
  static get TEXT_TERTIARY(): string { return AppThemeManager.isDarkMode() ? AppColors.TEXT_DARK_TERTIARY : AppColors.TEXT_TERTIARY_LIGHT }
  static get TEXT_HINT(): string { return AppThemeManager.isDarkMode() ? AppColors.TEXT_DARK_HINT : AppColors.TEXT_HINT_LIGHT }
  static get TEXT_DISABLED(): string { return AppThemeManager.isDarkMode() ? AppColors.TEXT_DARK_DISABLED : AppColors.TEXT_DISABLED_LIGHT }

  // 背景色阶 - 奶油风核心（动态）
  private static readonly BG_PRIMARY_LIGHT: string = '#F7F5F2'
  private static readonly BG_SECONDARY_LIGHT: string = 'rgba(255, 255, 255, 0.9)'
  private static readonly BG_TERTIARY_LIGHT: string = '#F0EFE9'
  private static readonly BG_GLASS_LIGHT: string = 'rgba(255, 255, 255, 0.7)'

  static get BG_PRIMARY(): string { return AppThemeManager.isDarkMode() ? AppColors.BG_DARK_PRIMARY : AppColors.BG_PRIMARY_LIGHT }
  static get BG_SECONDARY(): string { return AppThemeManager.isDarkMode() ? AppColors.BG_DARK_SECONDARY : AppColors.BG_SECONDARY_LIGHT }
  static get BG_TERTIARY(): string { return AppThemeManager.isDarkMode() ? AppColors.BG_DARK_TERTIARY : AppColors.BG_TERTIARY_LIGHT }
  static get BG_GLASS(): string { return AppThemeManager.isDarkMode() ? 'rgba(28, 28, 30, 0.7)' : AppColors.BG_GLASS_LIGHT }

  // 背景色阶 - 暗色模式 (暗夜级别深黑)
  static readonly BG_DARK_PRIMARY: string = '#000000'        // 纯黑背景
  static readonly BG_DARK_SECONDARY: string = '#1C1C1E'      // 卡片背景
  static readonly BG_DARK_TERTIARY: string = '#2C2C2E'       // 深灰底色
  static readonly BG_DARK_ELEVATED: string = '#3A3A3C'       // 悬浮元素

  // 文字色阶 - 暗色模式
  static readonly TEXT_DARK_PRIMARY: string = '#FFFFFF'      // 主文字白色
  static readonly TEXT_DARK_SECONDARY: string = '#EBEBF5'    // 次级文字
  static readonly TEXT_DARK_TERTIARY: string = '#8E8E93'     // 辅助文字
  static readonly TEXT_DARK_HINT: string = '#636366'         // 提示文字
  static readonly TEXT_DARK_DISABLED: string = '#48484A'     // 禁用文字

  // 边框色
  static readonly BORDER: string = 'rgba(0, 0, 0, 0.03)' // 极淡边框
  static readonly BORDER_LIGHT: string = 'rgba(255, 255, 255, 0.5)' // 高光边框

  // 分割线
  static readonly DIVIDER: string = 'rgba(0, 0, 0, 0.04)'
  static readonly DIVIDER_DARK: string = '#38383A'          // 暗色分割线

  // 暗色模式边框
  static readonly BORDER_DARK: string = 'rgba(255, 255, 255, 0.1)'

  // 阴影色
  static readonly SHADOW_LIGHT: string = 'rgba(0, 0, 0, 0.03)'

  // 纯色
  static readonly WHITE: string = '#FFFFFF'
  static readonly BLACK: string = '#000000'

  // 半透明遮罩
  static readonly OVERLAY_LIGHT: string = 'rgba(247, 245, 242, 0.8)'
  static readonly OVERLAY_DARK: string = 'rgba(28, 25, 23, 0.4)'

  // 录音状态专用色
  static readonly RECORDING: string = '#FF8533'
  static readonly RECORDING_ACTIVE: string = '#FF8533'
  static readonly RECORDING_BG: string = 'rgba(255, 133, 51, 0.1)'
  static readonly RECORDING_RIPPLE: string = 'rgba(255, 133, 51, 0.2)'
}

// ============================================================================
// 尺寸系统 - 大圆角、宽间距
// ============================================================================
export class AppSizes {
  // 间距 - 空气感
  static readonly SPACE_2XS: number = 4
  static readonly SPACE_XS: number = 8
  static readonly SPACE_SM: number = 12
  static readonly SPACE_MD: number = 16
  static readonly SPACE_LG: number = 24
  static readonly SPACE_XL: number = 32
  static readonly SPACE_2XL: number = 40
  static readonly SPACE_3XL: number = 48
  static readonly SPACE_4XL: number = 64
  static readonly SPACE_5XL: number = 80

  // 字体大小
  static readonly FONT_2XS: number = 10
  static readonly FONT_XS: number = 12
  static readonly FONT_SM: number = 14
  static readonly FONT_MD: number = 16
  static readonly FONT_LG: number = 18
  static readonly FONT_XL: number = 22
  static readonly FONT_2XL: number = 28
  static readonly FONT_3XL: number = 36
  static readonly FONT_DISPLAY: number = 56

  // 圆角 - Q弹感
  static readonly RADIUS_XS: number = 8
  static readonly RADIUS_SM: number = 12
  static readonly RADIUS_MD: number = 16
  static readonly RADIUS_LG: number = 24 // 卡片标准圆角
  static readonly RADIUS_XL: number = 32
  static readonly RADIUS_FULL: number = 9999

  // 图标尺寸
  static readonly ICON_XS: number = 16
  static readonly ICON_SM: number = 20
  static readonly ICON_MD: number = 24
  static readonly ICON_LG: number = 32
  static readonly ICON_XL: number = 48

  // 按钮高度
  static readonly BTN_SM: number = 36
  static readonly BTN_MD: number = 48
  static readonly BTN_LG: number = 56

  // 触摸区域最小尺寸
  static readonly TOUCH_MIN: number = 44
  static readonly TOUCH_COMFORTABLE: number = 56

  // 卡片
  static readonly CARD_PADDING: number = 20
  static readonly CARD_RADIUS: number = 24
}

// ============================================================================
// 阴影系统 - 空气悬浮感
// ============================================================================
export class AppShadows {
  // 极轻阴影 (Soft)
  static readonly SHADOW_XS: ShadowOptions = {
    radius: 6,
    color: 'rgba(0, 0, 0, 0.03)',
    offsetX: 0,
    offsetY: 2
  }

  // 轻阴影 (Card Default)
  static readonly SHADOW_SM: ShadowOptions = {
    radius: 12,
    color: 'rgba(0, 0, 0, 0.04)',
    offsetX: 0,
    offsetY: 4
  }

  // 中阴影 (Hover/Active) - 空气悬浮公式
  static readonly SHADOW_MD: ShadowOptions = {
    radius: 25,
    color: 'rgba(0, 0, 0, 0.05)',
    offsetX: 0,
    offsetY: 10
  }

  // 重阴影 (Modal/Float)
  static readonly SHADOW_LG: ShadowOptions = {
    radius: 40,
    color: 'rgba(0, 0, 0, 0.08)',
    offsetX: 0,
    offsetY: 20
  }
}

// 便捷函数：获取卡片阴影
export function getCardShadow(): ShadowOptions {
  return AppShadows.SHADOW_MD // 默认使用空气悬浮阴影
}

// ============================================================================
// 动效系统 - 柔和回弹
// ============================================================================
export class AppAnimations {
  // 即时响应
  static readonly DURATION_INSTANT: number = 150

  // 快速响应
  static readonly DURATION_FAST: number = 250

  // 标准动效
  static readonly DURATION_NORMAL: number = 350

  // 缓慢动效
  static readonly DURATION_SLOW: number = 500

  // 快速回弹
  static readonly SPRING_FAST: AnimateParam = {
    duration: 300,
    curve: Curve.FastOutSlowIn
  }

  // 标准回弹 (Q弹感)
  static readonly SPRING_NORMAL: AnimateParam = {
    duration: 400,
    curve: Curve.FastOutSlowIn
  }

  // 缓慢回弹
  static readonly SPRING_SLOW: AnimateParam = {
    duration: 600,
    curve: Curve.FastOutSlowIn
  }

  // 弹性动效
  static readonly SPRING_BOUNCE: AnimateParam = {
    duration: 500,
    curve: Curve.FastOutSlowIn
  }
}

// ============================================================================
// 渐变系统 - Swiss Spa风格（清新、简约、高级）
// ============================================================================
export class AppGradients {
  // 卡片微渐变
  static readonly CARD_SUBTLE: LinearGradient = {
    angle: 180,
    colors: [
      ['rgba(255, 255, 255, 0.8)', 0],
      ['rgba(255, 255, 255, 0.4)', 1]
    ]
  }

  // 暖色渐变 (用于背景装饰)
  static readonly WARM_GLOW: LinearGradient = {
    angle: 135,
    colors: [
      ['#FDE68A', 0], // 浅琥珀
      ['#FCA5A5', 1]  // 浅红
    ]
  }

  // 录音按钮渐变
  static readonly RECORDING_BTN: LinearGradient = {
    angle: 135,
    colors: [
      ['#FF9F43', 0],
      ['#FF6B6B', 1]
    ]
  }

  // 主按钮渐变
  static readonly PRIMARY_BTN: LinearGradient = {
    angle: 135,
    colors: [
      ['#cc785c', 0],
      ['#a9583e', 1]
    ]
  }
  
  // ===== Swiss Spa 风格渐变 =====
  
  // Spa薄荷绿（清新专注）
  static readonly SPA_MINT: LinearGradient = {
    angle: 135,
    colors: [
      ['#A7F3D0', 0],  // 薄荷绿
      ['#6EE7B7', 1]   // 翡翠绿
    ]
  }
  
  // Spa薰衣草（放松休息）
  static readonly SPA_LAVENDER: LinearGradient = {
    angle: 135,
    colors: [
      ['#DDD6FE', 0],  // 薰衣草紫
      ['#C4B5FD', 1]   // 淡紫罗兰
    ]
  }
  
  // Spa天空蓝（清透专业）
  static readonly SPA_SKY: LinearGradient = {
    angle: 135,
    colors: [
      ['#BAE6FD', 0],  // 天空蓝
      ['#7DD3FC', 1]   // 浅蓝
    ]
  }
  
  // Spa蜜桃（温暖鼓励）
  static readonly SPA_PEACH: LinearGradient = {
    angle: 135,
    colors: [
      ['#FED7AA', 0],  // 蜜桃
      ['#FDBA74', 1]   // 杏色
    ]
  }
  
  // Spa玫瑰金（高级奢华）
  static readonly SPA_ROSE: LinearGradient = {
    angle: 135,
    colors: [
      ['#FECDD3', 0],  // 玫瑰粉
      ['#FCA5A5', 1]   // 珊瑚红
    ]
  }
  
  // 极简白灰（Swiss设计核心）
  static readonly SWISS_MINIMAL: LinearGradient = {
    angle: 180,
    colors: [
      ['#FAFAFA', 0],  // 极白
      ['#F4F4F5', 1]   // 浅灰
    ]
  }
}

// 渐变颜色对
type GradientColorStop = [string, number]

// 线性渐变定义
export interface LinearGradient {
  angle: number
  colors: GradientColorStop[]
}
