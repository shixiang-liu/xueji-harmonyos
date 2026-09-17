// 持久化存储工具类 - 基于 Preferences 实现本地数据存储

import { preferences } from '@kit.ArkData'
import { ContentBlock, NoteItem } from '../../diary/model/NoteItem'
import common from '@ohos.app.ability.common'
import { CloudDiaryService } from '../services/CloudDiaryService'

// 通用偏好设置存储名
const COMMON_PREFERENCES_NAME = 'app_preferences'
// 日记专用存储名
const NOTES_PREFERENCES_NAME = 'myNotesData'
const NOTES_KEY = 'notesList'

// 全局上下文引用
let globalContext: common.Context | null = null

// 日记数据持久化工具类
export class PreferencesUtil {

  private static normalizeNoteMetadata(note: NoteItem): NoteItem {
    note.images = note.images || []
    note.videos = note.videos || []
    note.recordings = note.recordings || []
    note.contentBlocks = note.contentBlocks || []
    note.locationName = note.locationName || ''
    note.locationAddress = note.locationAddress || ''
    note.latitude = note.latitude || 0
    note.longitude = note.longitude || 0

    const hasImageBlock = note.contentBlocks.some((block: ContentBlock) => block.type === 'image')
    const hasVideoBlock = note.contentBlocks.some((block: ContentBlock) => block.type === 'video')
    const hasAudioBlock = note.contentBlocks.some((block: ContentBlock) => block.type === 'recording')

    note.hasImage = note.images.length > 0 || hasImageBlock
    note.hasVideo = note.videos.length > 0 || hasVideoBlock
    note.hasAudio = note.recordings.length > 0 || hasAudioBlock || !!note.audioPath

    const mediaTypes: string[] = []
    if (note.hasImage) {
      mediaTypes.push('image')
    }
    if (note.hasVideo) {
      mediaTypes.push('video')
    }
    if (note.hasAudio) {
      mediaTypes.push('audio')
    }
    note.mediaTypes = mediaTypes

    note.learningMoodLabel = note.emotionLabel || note.learningMoodLabel || ''
    note.learningMoodEmoji = note.emotionEmoji || note.learningMoodEmoji || ''
    return note
  }

  static normalizeNotes(notes: NoteItem[]): NoteItem[] {
    return notes.map((note: NoteItem) => PreferencesUtil.normalizeNoteMetadata(note))
  }

  // 初始化上下文（应用启动时调用）
  static initContext(context: common.Context): void {
    globalContext = context
  }

  // 获取上下文
  private static getContext(): common.Context {
    if (!globalContext) {
      throw new Error('PreferencesUtil 未初始化，请先调用 initContext')
    }
    return globalContext
  }

  // ==================== 通用键值存储 ====================

  // 存储任意值
  static async put(key: string, value: string | number | boolean): Promise<void> {
    const context = PreferencesUtil.getContext()
    const pref = await preferences.getPreferences(context, COMMON_PREFERENCES_NAME)
    await pref.put(key, value)
    await pref.flush()
  }

  // 获取值
  static async get<T>(key: string, defaultValue: T): Promise<T> {
    const context = PreferencesUtil.getContext()
    const pref = await preferences.getPreferences(context, COMMON_PREFERENCES_NAME)
    const result = await pref.get(key, defaultValue as preferences.ValueType)
    return result as T
  }

  // 删除指定键
  static async delete(key: string): Promise<void> {
    const context = PreferencesUtil.getContext()
    const pref = await preferences.getPreferences(context, COMMON_PREFERENCES_NAME)
    await pref.delete(key)
    await pref.flush()
  }

  // 获取对象（JSON反序列化）
  static async getObject<T>(key: string, defaultValue: T): Promise<T> {
    const jsonStr = await PreferencesUtil.get<string>(key, '')
    if (!jsonStr) {
      return defaultValue
    }
    return JSON.parse(jsonStr) as T
  }

  // 存储对象（JSON序列化）
  static async putObject<T>(key: string, value: T): Promise<void> {
    await PreferencesUtil.put(key, JSON.stringify(value))
  }

  // ==================== 日记专用方法 ====================

  // 加载日记列表
  static async loadNotes(context: common.Context): Promise<NoteItem[]> {
    try {
      console.info('[PreferencesUtil] 开始加载日记，context存在:', !!context)
      const pref = await preferences.getPreferences(context, NOTES_PREFERENCES_NAME)
      console.info('[PreferencesUtil] Preferences对象已获取')
      const notesJson: string = await pref.get(NOTES_KEY, '[]') as string
      console.info('[PreferencesUtil] 读取到JSON字符串，长度:', notesJson.length, '前100字符:', notesJson.substring(0, 100))
      const notes: NoteItem[] = PreferencesUtil.normalizeNotes(JSON.parse(notesJson) as NoteItem[])
      console.info('[PreferencesUtil] 解析完成，日记数量:', notes.length)
      if (notes.length > 0) {
        console.info('[PreferencesUtil] 第一条日记ID:', notes[0].id, '标题:', notes[0].title, 'createTime:', notes[0].createTime)
      }
      return notes
    } catch (err) {
      console.error('[PreferencesUtil] 加载日记失败:', err)
      console.error('[PreferencesUtil] 错误详情:', JSON.stringify(err))
      return []
    }
  }

  // 保存日记列表（本地 + 云端同步）
  static async saveNotes(context: common.Context, notes: NoteItem[], key?: string): Promise<void> {
    try {
      const normalizedNotes = PreferencesUtil.normalizeNotes(notes)
      console.info('[PreferencesUtil] 开始保存日记列表，数量:', normalizedNotes.length, 'context存在:', !!context)
      // 保存到本地
      const pref = await preferences.getPreferences(context, NOTES_PREFERENCES_NAME)
      const saveKey = key || NOTES_KEY
      const jsonStr = JSON.stringify(normalizedNotes)
      console.info('[PreferencesUtil] JSON字符串长度:', jsonStr.length, '前200字符:', jsonStr.substring(0, 200))
      await pref.put(saveKey, jsonStr)
      await pref.flush()
      console.info('[PreferencesUtil] 本地保存完成，日记数量:', normalizedNotes.length)
      
      // 验证保存是否成功
      const verifyJson: string = await pref.get(saveKey, '[]') as string
      const verifyNotes: NoteItem[] = JSON.parse(verifyJson)
      console.info('[PreferencesUtil] 验证保存结果，读取到的数量:', verifyNotes.length)
      if (verifyNotes.length !== normalizedNotes.length) {
        console.error('[PreferencesUtil] 警告：保存后验证数量不匹配！期望:', normalizedNotes.length, '实际:', verifyNotes.length)
      }

      // 异步同步到云端
      PreferencesUtil.syncToCloud(normalizedNotes).catch((err: Error) => {
        console.warn('[PreferencesUtil] 云端同步失败，记录已保存在本地:', err.message)
      })
    } catch (err) {
      console.error('[PreferencesUtil] 保存日记列表失败:', err)
      console.error('[PreferencesUtil] 错误详情:', JSON.stringify(err))
      throw err instanceof Error ? err : new Error(String(err))
    }
  }

  // 同步日记到云端
  private static async syncToCloud(notes: NoteItem[]): Promise<void> {
    const cloudService = CloudDiaryService.getInstance()
    const initialized = await cloudService.initialize()
    if (!initialized) {
      console.warn('[PreferencesUtil] CloudDB 未初始化，本次云同步待补偿')
      return
    }
    const success = await cloudService.saveNotes(notes)
    if (success) {
      console.info('[PreferencesUtil] 云端同步成功')
    }
  }

  // 保存单条日记
  static async saveNote(context: common.Context, note: NoteItem): Promise<void> {
    try {
      note = PreferencesUtil.normalizeNoteMetadata(note)
      console.info('[PreferencesUtil] 开始保存单条日记，ID:', note.id, '标题:', note.title)
      const notes = await PreferencesUtil.loadNotes(context)
      console.info('[PreferencesUtil] 当前日记列表数量:', notes.length)
      const index = notes.findIndex(n => n.id === note.id)
      if (index >= 0) {
        notes[index] = note
        console.info('[PreferencesUtil] 更新已存在的日记，索引:', index)
      } else {
        notes.unshift(note)
        console.info('[PreferencesUtil] 添加新日记，新列表数量:', notes.length)
      }
      await PreferencesUtil.saveNotes(context, notes)
      console.info('[PreferencesUtil] 单条日记保存完成，最终列表数量:', notes.length)
    } catch (err) {
      console.error('[PreferencesUtil] 保存单条日记失败:', err)
      console.error('[PreferencesUtil] 错误详情:', JSON.stringify(err))
      throw err instanceof Error ? err : new Error(String(err))
    }
  }

  // 清除所有数据（云端+本地）— 统一用 globalContext，避免与 put/get 用不同 context
  static async clearAllData(_context?: common.Context): Promise<void> {
    const ctx = PreferencesUtil.getContext()
    let localFailed = false

    // 1. 清除日记本地存储
    try {
      const notesPref = await preferences.getPreferences(ctx, NOTES_PREFERENCES_NAME)
      await notesPref.clear()
      await notesPref.flush()
      await preferences.deletePreferences(ctx, NOTES_PREFERENCES_NAME)
      console.info('[PreferencesUtil] 日记数据已清除')
    } catch (e) {
      localFailed = true
      console.error('[PreferencesUtil] 清除日记存储失败:', JSON.stringify(e))
    }

    // 2. 清除通用设置存储
    try {
      const commonPref = await preferences.getPreferences(ctx, COMMON_PREFERENCES_NAME)
      await commonPref.clear()
      await commonPref.flush()
      await preferences.deletePreferences(ctx, COMMON_PREFERENCES_NAME)
      console.info('[PreferencesUtil] 通用设置已清除')
    } catch (e) {
      localFailed = true
      console.error('[PreferencesUtil] 清除通用设置失败:', JSON.stringify(e))
    }

    if (localFailed) {
      throw new Error('本地存储清除失败')
    }

    // 3. Cloud-synced data 由调用方负责（避免在已 signOut 的状态下重复调用）
  }
}
