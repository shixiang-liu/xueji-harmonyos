/**
 * @file NoteItem.ets
 * @description 日记数据模型 - 定义日记及其内容块的数据结构
 */

import { RecordingItem } from './RecordingItem'

// ==================== 内容块类型定义 ====================

/** 内容块类型枚举 */
export type ContentBlockType = 'text' | 'image' | 'video' | 'link' | 'checklist' | 'table' | 'recording'

/**
 * 内容块基类
 * 所有具体内容块的父类，支持拖动排序
 */
@Observed
export class ContentBlock {
  /** 内容块唯一标识 */
  id: string = ''

  /** 内容块类型 */
  type: ContentBlockType = 'text'

  /** 排序序号 */
  order: number = 0

  constructor(type: ContentBlockType = 'text') {
    this.id = `block_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
    this.type = type
  }
}

/** 文本内容块 */
@Observed
export class TextBlock extends ContentBlock {
  text: string = ''

  constructor(text: string = '') {
    super('text')
    this.text = text
  }
}

/** 图片内容块 */
@Observed
export class ImageBlock extends ContentBlock {
  imagePath: string = ''

  constructor(imagePath: string = '') {
    super('image')
    this.imagePath = imagePath
  }
}

/** 视频内容块 */
@Observed
export class VideoBlock extends ContentBlock {
  videoPath: string = ''

  constructor(videoPath: string = '') {
    super('video')
    this.videoPath = videoPath
  }
}

/** 链接内容块 */
@Observed
export class LinkBlock extends ContentBlock {
  title: string = ''
  url: string = ''

  constructor(title: string = '', url: string = '') {
    super('link')
    this.title = title
    this.url = url
  }
}

/** 清单内容块 */
@Observed
export class ChecklistBlock extends ContentBlock {
  text: string = ''
  checked: boolean = false

  constructor(text: string = '', checked: boolean = false) {
    super('checklist')
    this.text = text
    this.checked = checked
  }
}

/** 表格内容块 */
@Observed
export class TableBlockContent extends ContentBlock {
  rows: string[][] = []

  constructor(rows: string[][] = [['', '', ''], ['', '', '']]) {
    super('table')
    this.rows = rows
  }
}

/** 录音内容块 */
@Observed
export class RecordingBlock extends ContentBlock {
  recording: RecordingItem = new RecordingItem()

  constructor(recording?: RecordingItem) {
    super('recording')
    if (recording) {
      this.recording = recording
    }
  }
}


// ==================== 日记数据模型 ====================

/**
 * 日记数据模型
 * 支持富文本、多媒体附件、内容块混排等功能
 */
export class NoteItem {
  /** 日记唯一标识符 */
  id: string = ''

  /** 日记标题 */
  title: string = ''

  /** 日记纯文本内容（向后兼容） */
  content: string = ''

  /** 日记分类 */
  category: string = ''

  /** 格式化的创建日期 */
  date: string = ''

  /** 创建时间戳（毫秒） */
  createTime: number = 0

  /** 最后修改时间戳（毫秒） */
  lastModifiedTime: number = 0

  /** 录音列表 */
  recordings: RecordingItem[] = []

  /** 删除时间戳（用于回收站功能） */
  deletedTime?: number = 0

  /** 是否已加锁 */
  isLocked?: boolean = false

  /** 加锁密码 */
  password?: string = ''

  /** 是否收藏 */
  isFavorite?: boolean = false

  // ==================== 情绪相关字段 ====================

  /** 情绪标签 */
  emotionLabel?: string = ''

  /** 情绪表情 */
  emotionEmoji?: string = ''

  /** 天气标签 */
  weatherLabel?: string = ''

  /** 天气图标 */
  weatherIcon?: string = ''

  /** 情绪对应颜色 */
  emotionColor?: string = ''

  /** 情绪分析置信度 */
  emotionConfidence?: number = 0

  /** 学习心情标签，复用 AI 情绪分析结果 */
  learningMoodLabel: string = ''

  /** 学习心情表情，复用 AI 情绪分析结果 */
  learningMoodEmoji: string = ''

  // ==================== 学习地点元数据 ====================

  /** 用户可读的学习地点名称，不直接展示经纬度 */
  locationName: string = ''

  /** 详细地点描述或地址 */
  locationAddress: string = ''

  /** 学习地点纬度，仅作为底层元数据 */
  latitude: number = 0

  /** 学习地点经度，仅作为底层元数据 */
  longitude: number = 0

  /** 图片附件路径列表 */
  images: string[] = []

  /** 视频附件路径列表 */
  videos: string[] = []

  /** 媒体类型摘要：image | video | audio */
  mediaTypes: string[] = []

  /** 是否包含图片 */
  hasImage: boolean = false

  /** 是否包含视频 */
  hasVideo: boolean = false

  /** 是否包含音频 */
  hasAudio: boolean = false

  /** 链接列表 */
  links: LinkItem[] = []

  /** 清单列表 */
  checklist: ChecklistItem[] = []

  /** 表格列表 */
  tables: TableBlock[] = []

  /** 内容块列表（支持混合内容和拖动排序） */
  contentBlocks: ContentBlock[] = []

  /** 是否已完成 AI 意图分析（用于避免重复弹窗） */
  intentAnalyzed?: boolean = false

  /** AI 意图分析完成时间戳 */
  intentAnalyzedAt?: number = 0

  // ==================== 复盘（reflection）相关字段 ====================

  /** 笔记类型：record（普通学习记录） | reflection（每日复盘卡片） */
  noteType?: string = 'record'

  /** 复盘日期，YYYY-MM-DD 格式，用于查询某天复盘 */
  reflectionDate?: string = ''

  /** 复盘对话历史（user/assistant 交替），仅 noteType=reflection 时使用 */
  reflectionMessages?: string = ''

  /** 复盘卡片提取的「学到」要点 */
  reflectionTakeaways?: string[] = []

  /** 复盘卡片提取的「困惑」未解决问题，第二天复盘会主动追问 */
  unresolvedQuestions?: string[] = []

  /** 复盘卡片提取的「明日计划」 */
  reflectionPlan?: string[] = []

  /** 困惑是否已解决（在后续复盘里被追问且确认） */
  questionsResolved?: boolean = false

  /** 
   * RichEditor 内容序列化数据（JSON 字符串）
   * 保存 span 的顺序和内容，用于精确恢复 RichEditor 状态
   * 格式: [{ type: 'text'|'image', value: string, src: string, start: number, end: number }]
   */
  richEditorSpans: string = '[]'

  // ========== 已废弃字段（向后兼容） ==========

  /** @deprecated 使用 recordings 代替 */
  audioPath?: string = ''

  /** @deprecated 使用 recordings 代替 */
  audioDuration?: number = 0
}

// ==================== 辅助数据模型 ====================

/** 链接项 */
export class LinkItem {
  id: string = ''
  title: string = ''
  url: string = ''
}

/** 清单项 */
export class ChecklistItem {
  id: string = ''
  text: string = ''
  checked: boolean = false
}

/** 表格块 */
export class TableBlock {
  id: string = ''
  rows: string[][] = []
}
