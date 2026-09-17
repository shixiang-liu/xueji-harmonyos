import { NoteItem } from '../model/NoteItem'
import { normalizeLearningCategory, REFLECTION_CATEGORY } from './LearningCategories'

const MAX_CONTEXT_RECORDS: number = 5

class CategoryCount {
  name: string = ''
  count: number = 0

  constructor(name: string, count: number) {
    this.name = name
    this.count = count
  }
}

export class LearningDaySummary {
  dayKey: string = ''
  recordCount: number = 0
  categoryLine: string = ''
  mediaLine: string = ''
  titleLine: string = ''
  promptContext: string = ''
}

export function formatLearningDayKey(timestamp: number): string {
  const date = new Date(timestamp)
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

export function buildLearningDaySummary(notes: NoteItem[], timestamp: number = Date.now()): LearningDaySummary {
  const summary = new LearningDaySummary()
  summary.dayKey = formatLearningDayKey(timestamp)

  const todayRecords = notes
    .filter((note: NoteItem) => isLearningRecordForDay(note, summary.dayKey))
    .sort((a: NoteItem, b: NoteItem) => (a.createTime || 0) - (b.createTime || 0))

  summary.recordCount = todayRecords.length
  summary.categoryLine = buildCategoryLine(todayRecords)
  summary.mediaLine = buildMediaLine(todayRecords)
  summary.titleLine = buildTitleLine(todayRecords)
  summary.promptContext = buildPromptContext(summary, todayRecords)
  return summary
}

function isLearningRecordForDay(note: NoteItem, dayKey: string): boolean {
  if (!note || !note.id) {
    return false
  }
  if (note.noteType === 'reflection' || normalizeLearningCategory(note.category) === REFLECTION_CATEGORY) {
    return false
  }
  if ((note.deletedTime || 0) > 0) {
    return false
  }
  const createTime = note.createTime || 0
  if (createTime > 0) {
    return formatLearningDayKey(createTime) === dayKey
  }
  return (note.date || '').indexOf(dayKey) === 0
}

function buildCategoryLine(records: NoteItem[]): string {
  const counts: CategoryCount[] = []
  for (const record of records) {
    const category = normalizeLearningCategory(record.category)
    const existing = counts.find((item: CategoryCount) => item.name === category)
    if (existing) {
      existing.count += 1
    } else {
      counts.push(new CategoryCount(category, 1))
    }
  }
  return counts
    .sort((a: CategoryCount, b: CategoryCount) => b.count - a.count)
    .map((item: CategoryCount) => `${item.name} ${item.count} 条`)
    .join('，')
}

function buildMediaLine(records: NoteItem[]): string {
  let audioCount = 0
  let imageCount = 0
  let videoCount = 0
  for (const record of records) {
    audioCount += record.recordings ? record.recordings.length : 0
    imageCount += record.images && record.images.length > 0 ? record.images.length : (record.hasImage ? 1 : 0)
    videoCount += record.videos && record.videos.length > 0 ? record.videos.length : (record.hasVideo ? 1 : 0)
  }

  const parts: string[] = []
  if (audioCount > 0) {
    parts.push(`录音 ${audioCount} 条`)
  }
  if (imageCount > 0) {
    parts.push(`图片 ${imageCount} 张`)
  }
  if (videoCount > 0) {
    parts.push(`视频 ${videoCount} 个`)
  }
  return parts.join('，')
}

function buildTitleLine(records: NoteItem[]): string {
  return records
    .slice(0, 3)
    .map((record: NoteItem) => sanitizeText(record.title || record.content || '未命名记录', 18))
    .join(' / ')
}

function buildPromptContext(summary: LearningDaySummary, records: NoteItem[]): string {
  if (summary.recordCount === 0) {
    return '今天还没有普通学习记录。复盘时先询问用户今天是否有想补充记录的学习内容。'
  }

  const lines: string[] = [
    `今天共有 ${summary.recordCount} 条普通学习记录。`,
    summary.categoryLine ? `分类分布：${summary.categoryLine}。` : '',
    summary.mediaLine ? `多媒体证据：${summary.mediaLine}。` : ''
  ].filter((line: string) => line.length > 0)

  const recordLines = records.slice(0, MAX_CONTEXT_RECORDS).map((record: NoteItem, index: number) => {
    const title = sanitizeText(record.title || '未命名记录', 24)
    const category = normalizeLearningCategory(record.category)
    const content = sanitizeText(record.content || collectRecordingText(record), 80)
    return `${index + 1}. ${category}《${title}》${content ? `：${content}` : ''}`
  })

  if (recordLines.length > 0) {
    lines.push('今日记录摘录：')
    lines.push(recordLines.join('\n'))
  }
  return lines.join('\n')
}

function collectRecordingText(record: NoteItem): string {
  if (!record.recordings || record.recordings.length === 0) {
    return ''
  }
  return record.recordings
    .map(item => item.transcription || '')
    .filter(text => text.length > 0)
    .join(' ')
}

function sanitizeText(text: string, maxLength: number): string {
  const value = (text || '').replace(/\s+/g, ' ').trim()
  if (value.length <= maxLength) {
    return value
  }
  return value.substring(0, maxLength) + '...'
}
