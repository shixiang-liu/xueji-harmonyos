// ============================================================================
// SVG 图标组件 - SvgIcon
// ============================================================================
// 功能：统一渲染 SVG 路径图标
// 用途：替代所有 emoji 和 Unicode 符号
// 依赖：IconPaths.ets 中的 SVG 路径定义
// ============================================================================

import { IconPaths, IconSize } from '../utils/IconPaths';

// ============================================================================
// SVG 图标组件
// ============================================================================
@Component
export struct SvgIcon {
  // SVG 路径数据
  @Prop path: string = '';
  
  // 图标尺寸
  @Prop size: number = IconSize.MD;
  
  // 图标颜色
  @Prop color: string = '#1C1917';
  
  // 填充模式：fill（填充）、stroke（描边）
  @Prop fillMode: string = 'fill';
  
  // 描边宽度（仅 stroke 模式有效）
  @Prop strokeWidth: number = 1.5;

  build() {
    // 使用 Shape + Path 渲染 SVG
    Shape() {
      Path()
        .commands(this.path)
    }
    .width(this.size)
    .height(this.size)
    .viewPort({ x: 0, y: 0, width: 24, height: 24 })
    .fill(this.fillMode === 'fill' ? this.color : 'none')
    .stroke(this.fillMode === 'stroke' ? this.color : 'none')
    .strokeWidth(this.strokeWidth)
  }
}

// ============================================================================
// 预定义图标组件 - 便捷使用
// ============================================================================

// 返回箭头图标
@Component
export struct IconArrowBack {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.ARROW_BACK, size: this.size, color: this.color })
  }
}

// 向右箭头图标
@Component
export struct IconArrowForward {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.ARROW_FORWARD, size: this.size, color: this.color })
  }
}

// 关闭图标
@Component
export struct IconClose {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.CLOSE, size: this.size, color: this.color })
  }
}

// 菜单图标
@Component
export struct IconMenu {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MENU, size: this.size, color: this.color })
  }
}

// 更多（竖向三点）
@Component
export struct IconMoreVert {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MORE_VERT, size: this.size, color: this.color })
  }
}

// 添加图标
@Component
export struct IconAdd {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.ADD, size: this.size, color: this.color })
  }
}

// 删除图标
@Component
export struct IconDelete {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.DELETE, size: this.size, color: this.color })
  }
}

// 编辑图标
@Component
export struct IconEdit {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.EDIT, size: this.size, color: this.color })
  }
}

// 搜索图标
@Component
export struct IconSearch {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.SEARCH, size: this.size, color: this.color })
  }
}

// 设置图标
@Component
export struct IconSettings {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.SETTINGS, size: this.size, color: this.color })
  }
}

// 时钟图标
@Component
export struct IconTime {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.TIME, size: this.size, color: this.color })
  }
}

// 闹钟图标
@Component
export struct IconAlarm {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.ALARM, size: this.size, color: this.color })
  }
}

// 日历图标
@Component
export struct IconCalendar {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.CALENDAR, size: this.size, color: this.color })
  }
}

// 播放图标
@Component
export struct IconPlay {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.PLAY, size: this.size, color: this.color })
  }
}

// 暂停图标
@Component
export struct IconPause {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.PAUSE, size: this.size, color: this.color })
  }
}

// 停止图标
@Component
export struct IconStop {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.STOP, size: this.size, color: this.color })
  }
}

// 麦克风图标
@Component
export struct IconMic {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MIC, size: this.size, color: this.color })
  }
}

// 音量图标
@Component
export struct IconVolume {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.VOLUME, size: this.size, color: this.color })
  }
}

// 勾选图标
@Component
export struct IconCheck {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.CHECK, size: this.size, color: this.color })
  }
}

// 勾选圆形图标
@Component
export struct IconCheckCircle {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.CHECK_CIRCLE, size: this.size, color: this.color })
  }
}

// 星星（实心）
@Component
export struct IconStar {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.STAR, size: this.size, color: this.color })
  }
}

// 星星（空心）
@Component
export struct IconStarOutline {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.STAR_OUTLINE, size: this.size, color: this.color })
  }
}

// 心形（实心）
@Component
export struct IconHeart {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.HEART, size: this.size, color: this.color })
  }
}

// 锁定图标
@Component
export struct IconLock {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.LOCK, size: this.size, color: this.color })
  }
}

// 笔记本图标
@Component
export struct IconNotebook {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.NOTEBOOK, size: this.size, color: this.color })
  }
}

// 文档图标
@Component
export struct IconDocument {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.DOCUMENT, size: this.size, color: this.color })
  }
}

// 文件夹图标
@Component
export struct IconFolder {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.FOLDER, size: this.size, color: this.color })
  }
}

// 位置图标
@Component
export struct IconLocation {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.LOCATION, size: this.size, color: this.color })
  }
}

// 开心表情
@Component
export struct IconMoodHappy {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MOOD_HAPPY, size: this.size, color: this.color })
  }
}

// 中性表情
@Component
export struct IconMoodNeutral {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MOOD_NEUTRAL, size: this.size, color: this.color })
  }
}

// 难过表情
@Component
export struct IconMoodSad {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.MOOD_SAD, size: this.size, color: this.color })
  }
}

// 晴天图标
@Component
export struct IconSunny {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.WEATHER_SUNNY, size: this.size, color: this.color })
  }
}

// 标签图标
@Component
export struct IconTag {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.TAG, size: this.size, color: this.color })
  }
}

// 清单图标
@Component
export struct IconChecklist {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.CHECKLIST, size: this.size, color: this.color })
  }
}

// 表格图标
@Component
export struct IconTable {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.TABLE, size: this.size, color: this.color })
  }
}

// 展开/全屏图标
@Component
export struct IconExpand {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.EXPAND, size: this.size, color: this.color })
  }
}

// 收缩图标
@Component
export struct IconShrink {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.SHRINK, size: this.size, color: this.color })
  }
}

// 下载图标
@Component
export struct IconDownload {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.DOWNLOAD, size: this.size, color: this.color })
  }
}

// 上传图标
@Component
export struct IconUpload {
  @Prop size: number = IconSize.MD;
  @Prop color: string = '#1C1917';

  build() {
    SvgIcon({ path: IconPaths.UPLOAD, size: this.size, color: this.color })
  }
}
