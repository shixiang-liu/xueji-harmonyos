
/**
 * @file DetailPage.ets
 * @description 日记详情编辑页面 - 重构版 (MVVM 组件化)
 */
import { router, promptAction } from '@kit.ArkUI'
import common from '@ohos.app.ability.common'
import photoAccessHelper from '@ohos.file.photoAccessHelper'
import { fileUri } from '@kit.CoreFileKit'
import fs from '@ohos.file.fs'
import window from '@ohos.window'

import { NoteItem, ChecklistItem, LinkItem, LinkBlock, ContentBlock, TextBlock, ImageBlock, VideoBlock } from '../../model/NoteItem'
import { RecordingItem } from '../../model/RecordingItem'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { RecordingService, ASRCallbacks } from '../../../common/services/RecordingService'
import * as DiaryUtils from '../../../common/utils/DiaryUtils'
import { AudioPlayer } from '../../../common/utils/AudioPlayer'
import { AppColors, AppShadows, AppGradients, AppSizes, LinearGradient } from '../../../common/utils/AppTheme'
import { IconImage } from '../../../common/components/IconImage'
import { EmotionAnalyzer, EmotionAnalysisResult, EmotionPreset, EMOTION_PRESETS } from '../../../common/utils/EmotionAnalyzer'
import { LongCatService, IntentResult } from '../../../common/services/LongCatService'
import { IntentViewModel, DiaryAnalysisResult } from '../../viewmodel/IntentViewModel'
import { DiaryTopBar, DiaryBottomBar } from '../components/DiaryToolBar'
import { NoteEditView, NoteEditController } from '../components/NoteEditView'
import { EmotionPanel } from '../components/EmotionPanel'
import { CategoryPickerDialog, LockDialog, UnlockDialog } from '../components/DiaryDialogs'
import { InsertMenuDialog, LinkDialog, ChecklistDialog } from '../components/InsertMenu'
import { AudioRecordingOverlay } from '../components/AudioRecordingOverlay'
import { LearningLocationRow } from '../components/LearningLocationRow'
import { LocationService, LearningLocation } from '../../services/LocationService'
import { MediaCaptureService, CapturedMedia } from '../../services/MediaCaptureService'
import { DEFAULT_LEARNING_CATEGORIES, normalizeLearningCategory } from '../../utils/LearningCategories'
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab'

/** 波纹数据接口 */
interface RippleData {
  radius: number
  opacity: number
  speed: number
  lineWidth: number
}

/** Span信息接口（用于构建richEditorSpans） */
interface SpanData {
  type: string
  value?: string
  src?: string
  width?: number
  height?: number
  linkTitle?: string
  linkUrl?: string
}

@Entry
@Component
struct DetailPage {
  @State noteId: string = ''
  @State note: NoteItem = new NoteItem()
  
  // 安全区高度
  @State topSafeHeight: number = 0
  @State bottomSafeHeight: number = 0
  
  // 编辑器状态（与 NoteEditView 同步）
  @State titleText: string = ''
  @State @Watch('onContentTextChanged') contentText: string = ''
  @State recordings: RecordingItem[] = []
  @State checklistItems: ChecklistItem[] = []
  @State canUndo: boolean = false
  @State canRedo: boolean = false
  
  // 弹窗状态
  @State showInsertMenu: boolean = false
  @State showEmotionPanel: boolean = false
  @State showCategoryPicker: boolean = false
  @State showLockDialog: boolean = false
  @State showUnlockDialog: boolean = false
  @State showLinkDialog: boolean = false
  @State showChecklistDialog: boolean = false
  @State showRecordingOverlay: boolean = false

  // 学习地点元数据。界面只显示地点文本，经纬度仅保存为底层元数据。
  @State locationName: string = ''
  @State locationAddress: string = ''
  @State latitude: number = 0
  @State longitude: number = 0

  // 预解锁标志
  private isPreUnlocked: boolean = false
  
  // 待插入的链接数据
  private pendingLinkData: Record<string, string> | null = null
  
  // 分类列表
  @State categories: string[] = DEFAULT_LEARNING_CATEGORIES

  // 使用独立的分类状态变量，避免$note.category嵌套绑定导致闪退
  @State @Watch('onCategoryChange') selectedCategory: string = '课程'
  
  // 临时状态（用于弹窗交互）
  @State tempLinkTitle: string = ''
  @State tempLinkUrl: string = ''
  @State checklistInput: string = ''
  @State passwordInput: string = ''
  @State confirmPasswordInput: string = ''
  
  // 情绪分析状态
  @State isEmotionAnalyzing: boolean = false
  @State emotionStatusText: string = '等待分析'
  @State emotionAnalysisError: string = ''
  @State selectedEmotionEmoji: string = '😐'
  @State selectedEmotionLabel: string = '平淡'
  @State selectedEmotionKey: string = 'neutral'
  @State selectedWeatherIcon: string = '☁️'
  @State selectedWeatherLabel: string = '多云'
  @State emotionColor: string = '#9CA3AF'
  @State emotionConfidence: number = 0
  
  // 录音状态
  @State isRecording: boolean = false
  @State isProcessing: boolean = false
  @State recordingSeconds: number = 0
  @State waveHeights: number[] = [20, 35, 25, 40, 30, 45, 28, 38, 22, 42, 32, 36]
  @State pulseScale: number = 1
  @State currentVolume: number = 0
  
  // AI分析弹窗控制器

  @State realTimeTranscription: string = ''
  @State isSlideCancelling: boolean = false  // 上滑取消状态
  private lastASRLength: number = 0
  private recordStartY: number = 0  // 录音开始时的Y坐标
  
  // 播放状态
  @State isPlaying: boolean = false
  @State currentPlayingId: string = ''
  @State playbackProgress: number = 0
  @State currentDuration: number = 0
  
  // 控制器
  @State noteEditController: NoteEditController = new NoteEditController()
  @State selectedMediaImage: string = ''
  @State selectedMediaVideo: string = ''
  @State locationStatus: string = '' // '' | 'fetching' | 'success' | 'error'
  @State locationStatusMessage: string = ''
  // AI 智能标签建议
  @State suggestedTags: string[] = []
  @State isAnalyzingTags: boolean = false
  private tagDebounceTimer: number = -1
  private lastAnalyzedTagsLen: number = 0
  private hasAutoRequestedLocation: boolean = false
  private isGeneratingTitle: boolean = false

  // 服务实例
  private recordingService: RecordingService = RecordingService.getInstance()
  private audioPlayer: AudioPlayer = new AudioPlayer()
  private emotionAnalyzer: EmotionAnalyzer = EmotionAnalyzer.getInstance()
  private longCatService: LongCatService = LongCatService.getInstance()
  
  private emotionAnalysisTimer: number = 0
  private uiTimer: number = 0 // Modified from waveAnimationTimer
  private playbackTimer: number = 0
  private saveTimer: number = 0

  // 波纹动画相关 // Added
  private waveCanvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private waveCanvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.waveCanvasSettings)
  private ripples: Array<RippleData> = []
  private rippleAnimationTimer: number = 0
  private lastRippleTime: number = 0
  private frameCount: number = 0
  
  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext

  // 页面生命周期
  aboutToAppear(): void {
    this.setFullScreen()
    const params = router.getParams() as Record<string, Object>
    // 问题11修复：预解锁标志（从LockedNotesPage已验证过密码）
    let preUnlocked = false
    // 修复：记录是否是新建日记（有初始内容但没有noteId）
    let isNewNoteWithContent = false
    if (params) {
      if (params['noteId']) {
        this.noteId = params['noteId'] as string
      } else if (params['initialTitle'] || params['initialContent']) {
        // 如果没有noteId但有初始内容，说明是新建日记
        isNewNoteWithContent = true
      }
      // 检查是否已预先解锁
      if (params['preUnlocked']) {
        preUnlocked = params['preUnlocked'] as boolean
      }
      // External content integration: pre-fill note content
      if (params['initialTitle']) {
        this.titleText = params['initialTitle'] as string
      }
      if (params['initialContent']) {
        this.contentText = params['initialContent'] as string
      }
      // 处理从链接预览页传递的超链接信息
      if (params['initialLink']) {
        const linkData = params['initialLink'] as Record<string, string>
        if (linkData && linkData.title && linkData.url) {
          // 保存链接数据，等待编辑器准备好后插入
          this.pendingLinkData = linkData
        }
      }
    }
    
    // 保存预解锁状态供loadNote使用
    this.isPreUnlocked = preUnlocked
    
    // 初始化服务
    this.initServices()
    // 加载日记
    this.loadNote()
    setTimeout(() => {
      this.autoCaptureLearningLocation()
    }, 900)
    
    // 如果是新建日记且有初始内容，立即保存一次确保日记被创建
    // 注意：loadNote()会创建新的note对象，所以这里需要等待loadNote完成
    setTimeout(async () => {
      // 检查是否是新建日记（有初始内容但没有从数据库加载）
      if (isNewNoteWithContent && this.note && this.note.id) {
        // 确保内容已同步到note对象（再次确认，因为loadNote可能重置了）
        this.note.title = this.titleText || ''
        this.note.content = this.contentText || ''
        
        // 如果richEditorSpans还没有设置，手动构建它
        // 这样可以确保内容（包括链接）被正确保存
        if (!this.note.richEditorSpans || this.note.richEditorSpans === '[]') {
          const spanInfos: SpanData[] = []
          // 添加文本内容
          if (this.contentText && this.contentText.trim() !== '') {
            const textSpan: SpanData = { type: 'text', value: this.contentText }
            spanInfos.push(textSpan)
            console.info('[DetailPage] 添加文本内容到richEditorSpans，长度:', this.contentText.length)
          }
          // 添加链接（从pendingLinkData或note.links）
          if (this.pendingLinkData) {
            const linkSpan: SpanData = { 
              type: 'link', 
              linkTitle: this.pendingLinkData.title, 
              linkUrl: this.pendingLinkData.url 
            }
            spanInfos.push(linkSpan)
            // 同时添加到note.links
            if (!this.note.links) {
              this.note.links = []
            }
            const linkItem = new LinkItem()
            linkItem.id = Date.now().toString()
            linkItem.title = this.pendingLinkData.title
            linkItem.url = this.pendingLinkData.url
            this.note.links.push(linkItem)
            console.info('[DetailPage] 添加链接到richEditorSpans:', this.pendingLinkData.title)
          } else if (this.note.links && this.note.links.length > 0) {
            this.note.links.forEach(link => {
              const linkSpan: SpanData = { 
                type: 'link', 
                linkTitle: link.title, 
                linkUrl: link.url 
              }
              spanInfos.push(linkSpan)
            })
          }
          if (spanInfos.length > 0) {
            this.note.richEditorSpans = JSON.stringify(spanInfos)
            console.info('[DetailPage] 手动构建richEditorSpans，包含', spanInfos.length, '个元素，JSON长度:', this.note.richEditorSpans.length)
          } else {
            console.warn('[DetailPage] 警告：没有内容可以添加到richEditorSpans')
          }
        }
        
        // 再次确保note.content被设置（重要！）
        if (!this.note.content || this.note.content.trim() === '') {
          this.note.content = this.contentText || ''
          console.info('[DetailPage] 修复：设置note.content，长度:', this.note.content.length)
        }
        
        // 立即保存确保日记被创建
        await this.saveNote()
        console.info('[DetailPage] 新建日记已保存，ID:', this.note.id, '标题:', this.note.title, '内容长度:', this.note.content?.length || 0, 'richEditorSpans长度:', this.note.richEditorSpans?.length || 0)
        // 显示保存成功提示
        promptAction.showToast({ message: '记录已创建', duration: 1500 })
      }
    }, 1500)  // 等待编辑器初始化和链接插入完成
  }
  
  async setFullScreen() {
    try {
      const windowClass = await window.getLastWindow(getContext(this))
      await windowClass.setWindowLayoutFullScreen(true)
      const avoidArea = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topSafeHeight = px2vp(avoidArea.topRect.height)
      this.bottomSafeHeight = px2vp(avoidArea.bottomRect.height)
    } catch (e) {
      this.topSafeHeight = 44
      this.bottomSafeHeight = 34
    }
  }
  
  onPageHide(): void {
    this.stopPlayback()
    // 修复：保存前确保内容已同步
    // 通过触发一次内容变化来确保RichEditor内容已同步
    if (this.contentText) {
      this.note.content = this.contentText
    }
    
    // 修复：如果note.links有内容但richEditorSpans中没有，确保richEditorSpans包含链接
    if (this.note.links && this.note.links.length > 0) {
      try {
        let spans: SpanData[] = []
        if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
          spans = JSON.parse(this.note.richEditorSpans) as SpanData[]
        }
        
        // 检查richEditorSpans中是否包含所有链接
        const linkUrlsInSpans = new Set(spans.filter(s => s.type === 'link').map(s => s.linkUrl))
        let needUpdate = false
        
        for (const link of this.note.links) {
          if (!linkUrlsInSpans.has(link.url)) {
            spans.push({
              type: 'link',
              linkTitle: link.title,
              linkUrl: link.url
            })
            needUpdate = true
            console.info('[DetailPage] onPageHide: 添加缺失的链接到richEditorSpans:', link.title)
          }
        }
        
        // 如果没有文本内容但有链接，至少添加文本占位符
        const hasText = spans.some(s => s.type === 'text' && s.value && s.value.trim() !== '')
        if (!hasText && spans.length > 0) {
          // 如果有链接但没有文本，至少保留一个空文本或者从note.content创建
          if (this.note.content && this.note.content.trim() !== '') {
            spans.unshift({
              type: 'text',
              value: this.note.content
            })
            needUpdate = true
          }
        }
        
        if (needUpdate) {
          this.note.richEditorSpans = JSON.stringify(spans)
          console.info('[DetailPage] onPageHide: 更新richEditorSpans，包含', spans.length, '个元素')
        }
      } catch (e) {
        console.warn('[DetailPage] onPageHide: 检查richEditorSpans失败:', e)
      }
    }
    
    this.saveNote() // 立即保存

    // 如果离开时仍是空笔记，从存储中清理掉，避免首页出现空记录
    if (this.isNoteEmpty()) {
      this.purgeEmptyNote()
    }
  }

  /** 从 Preferences 中删除当前的空 note（不进回收站，直接清掉） */
  private async purgeEmptyNote(): Promise<void> {
    try {
      if (!this.note || !this.note.id) return
      const notes = await PreferencesUtil.loadNotes(this.context)
      const filtered = notes.filter((n: NoteItem) => n.id !== this.note.id)
      if (filtered.length !== notes.length) {
        await PreferencesUtil.saveNotes(this.context, filtered)
        AppStorage.setOrCreate('diaryUpdatedAt', Date.now())
        console.info('[DetailPage] 已清理空笔记 id:', this.note.id)
      }
    } catch (e) {
      console.warn('[DetailPage] 清理空笔记失败:', e)
    }
  }
  
  aboutToDisappear(): void {
    this.recordingService.release()
    this.audioPlayer.release()
    this.stopRippleAnimation() // Added
    this.stopUITimer() // Added
  }
  
  // 初始化服务
  private initServices(): void {
    this.recordingService.init()
    this.audioPlayer.init()
  }
  
  private stopPlayback(): void {
     this.audioPlayer.stop()
     this.isPlaying = false
     this.currentPlayingId = ''
     this.playbackProgress = 0
     if (this.playbackTimer) {
        clearInterval(this.playbackTimer)
        this.playbackTimer = 0
     }
  }

  // 加载日记数据
  async loadNote(): Promise<void> {
    if (this.noteId) {
      const notes = await PreferencesUtil.loadNotes(this.context)
      const loaded = notes.find(n => n.id === this.noteId)
      if (loaded) {
        this.note = loaded
        this.titleText = loaded.title || ''
        this.contentText = loaded.content || ''
        this.recordings = loaded.recordings || []
        this.checklistItems = loaded.checklist || [] 
        this.initEmotionState(loaded)
        // 问题4修复：初始化分类状态
        this.selectedCategory = normalizeLearningCategory(loaded.category)
        this.locationName = loaded.locationName || ''
        this.locationAddress = loaded.locationAddress || ''
        this.latitude = loaded.latitude || 0
        this.longitude = loaded.longitude || 0
        
        // 修复：调试信息 - 检查加载的内容
        console.info('[DetailPage] 加载日记，ID:', loaded.id, '标题:', loaded.title, 'content长度:', loaded.content?.length || 0, 'richEditorSpans长度:', loaded.richEditorSpans?.length || 0, 'links数量:', loaded.links?.length || 0)
        
        // 修复：确保links数组被正确加载
        if (loaded.links && loaded.links.length > 0) {
          console.info('[DetailPage] 加载日记，包含', loaded.links.length, '个链接')
        }
        
        // 修复：如果content为空但richEditorSpans存在，从richEditorSpans中提取文本
        if ((!this.contentText || this.contentText.trim() === '') && loaded.richEditorSpans && loaded.richEditorSpans !== '[]') {
          try {
            const spanDataList: SpanData[] = JSON.parse(loaded.richEditorSpans) as SpanData[]
            let textContent = ''
            for (const spanData of spanDataList) {
              if (spanData.type === 'text' && spanData.value) {
                textContent += spanData.value
              }
            }
            if (textContent) {
              this.contentText = textContent
              this.note.content = textContent
              console.info('[DetailPage] 从richEditorSpans恢复文本内容，长度:', textContent.length)
            } else {
              console.warn('[DetailPage] richEditorSpans中没有文本内容，但可能有链接或媒体内容')
              // 即使没有文本，也确保content至少是空字符串，这样richEditorSpans中的链接也能显示
              this.contentText = ''
              this.note.content = ''
            }
          } catch (e) {
            console.warn('[DetailPage] 从richEditorSpans提取文本失败:', e)
          }
        }
        
        // 修复：如果content和richEditorSpans都为空，记录警告
        if ((!this.contentText || this.contentText.trim() === '') && (!loaded.richEditorSpans || loaded.richEditorSpans === '[]')) {
          console.warn('[DetailPage] 警告：日记内容为空！ID:', loaded.id, '标题:', loaded.title)
        }
        
        // 问题11修复：如果已预先解锁(从LockedNotesPage进入)则跳过密码验证
        if (loaded.isLocked && !this.isPreUnlocked) {
           this.showUnlockDialog = true
        }
        
        // 修复：加载完成后，记录日志便于调试
        setTimeout(() => {
          console.info('[DetailPage] loadNote完成，contentText长度:', this.contentText.length, 'note.content长度:', this.note.content?.length || 0, 'richEditorSpans长度:', this.note.richEditorSpans?.length || 0, 'links数量:', this.note.links?.length || 0)
        }, 300)
      }
    } else {
      // New Note
      this.note = new NoteItem()
      this.note.id = Date.now().toString()
      this.note.createTime = Date.now()
      this.noteId = this.note.id
      // Keep pre-filled values if they exist, otherwise empty
      this.titleText = this.titleText || ''
      this.contentText = this.contentText || ''
      // 修复：确保新建日记时，note对象也包含初始内容
      this.note.title = this.titleText
      this.note.content = this.contentText
      this.locationName = ''
      this.locationAddress = ''
      this.latitude = 0
      this.longitude = 0
      console.info('[DetailPage] 新建日记，ID:', this.note.id, '标题:', this.titleText, '内容长度:', this.contentText.length)
      
      // 修复：同步初始值到note对象
      this.note.title = this.titleText
      this.note.content = this.contentText
      
      // 修复：如果是新建日记且有初始内容，立即保存一次
      // 但需要等待RichEditor初始化完成，所以延迟更长
      if (this.titleText || this.contentText) {
        // 延迟保存，确保RichEditor和链接都初始化完成
        setTimeout(async () => {
          // 再次确保内容同步
          this.note.title = this.titleText
          this.note.content = this.contentText
          await this.saveNote()
          console.info('[DetailPage] 新建日记已立即保存，ID:', this.note.id, '内容:', this.contentText.substring(0, 50))
        }, 1500)  // 增加延迟，确保链接插入完成
      }
    }
  }
  
  private initEmotionState(note: NoteItem): void {
     const moodLabel = note.emotionLabel || note.learningMoodLabel || ''
     const moodEmoji = note.emotionEmoji || note.learningMoodEmoji || '😐'
     if (moodLabel) {
        this.selectedEmotionLabel = moodLabel
        this.selectedEmotionEmoji = moodEmoji
        this.selectedWeatherLabel = note.weatherLabel || '多云'
        this.selectedWeatherIcon = note.weatherIcon || '☁️'
        this.emotionColor = note.emotionColor || '#9CA3AF'
        this.emotionStatusText = `情绪：${moodLabel}`
     }
  }

  /**
   * 判断当前笔记是否为空：标题、正文、录音、清单、链接、媒体全无
   * 用于阻止保存空白笔记，以及离开页面时清理空记录
   */
  private isNoteEmpty(): boolean {
    const titleEmpty = (this.titleText || '').trim().length === 0
    const contentEmpty = (this.contentText || this.note.content || '').trim().length === 0
    const noRecordings = !this.recordings || this.recordings.length === 0
    const noChecklist = !this.checklistItems || this.checklistItems.length === 0
    const noLinks = !this.note.links || this.note.links.length === 0
    const noMediaSpans = (() => {
      const spans = this.note.richEditorSpans
      if (!spans || spans === '[]') return true
      try {
        const list: SpanData[] = JSON.parse(spans) as SpanData[]
        // 富文本里只要有 image/video/audio 任意一种媒体就不算空
        return !list.some((s: SpanData) =>
          s.type === 'image' || s.type === 'video' || s.type === 'audio')
      } catch (e) {
        return true
      }
    })()
    return titleEmpty && contentEmpty && noRecordings && noChecklist && noLinks && noMediaSpans
  }

  private syncMediaMetadataBeforeSave(): void {
    this.note.images = this.note.images || []
    this.note.videos = this.note.videos || []
    this.note.recordings = this.recordings || []
    this.note.contentBlocks = this.note.contentBlocks || []

    const hasImageBlock = this.note.contentBlocks.some((block: ContentBlock) => block.type === 'image')
    const hasVideoBlock = this.note.contentBlocks.some((block: ContentBlock) => block.type === 'video')
    const hasAudioBlock = this.note.contentBlocks.some((block: ContentBlock) => block.type === 'recording')

    this.note.hasImage = this.note.images.length > 0 || hasImageBlock
    this.note.hasVideo = this.note.videos.length > 0 || hasVideoBlock
    this.note.hasAudio = this.note.recordings.length > 0 || hasAudioBlock || !!this.note.audioPath

    const mediaTypes: string[] = []
    if (this.note.hasImage) {
      mediaTypes.push('image')
    }
    if (this.note.hasVideo) {
      mediaTypes.push('video')
    }
    if (this.note.hasAudio) {
      mediaTypes.push('audio')
    }
    this.note.mediaTypes = mediaTypes
  }

  private async ensureAutoTitle(): Promise<void> {
    if (this.titleText.trim().length > 0 || this.isGeneratingTitle) {
      return
    }
    const source = (this.contentText || this.note.content || '').replace(/\s+/g, ' ').trim()
    if (source.length < 8) {
      return
    }
    this.isGeneratingTitle = true
    let title = ''
    try {
      const systemPrompt = `你是学习笔记标题生成器。根据用户笔记内容生成一个中文标题。
要求：只返回标题本身；不超过 14 个中文字符；不要加引号、冒号、句号；简洁具体。`
      title = await this.longCatService.chatLite(source.substring(0, 900), systemPrompt, false)
    } catch (e) {
      console.warn('[DetailPage] 自动生成标题失败，使用本地兜底:', e)
    }
    this.titleText = this.normalizeAutoTitle(title, source)
    this.isGeneratingTitle = false
  }

  private normalizeAutoTitle(rawTitle: string, source: string): string {
    let title = (rawTitle || '').replace(/\n/g, ' ').replace(/[《》「」"']/g, '').trim()
    if (title.length === 0) {
      title = source
    }
    title = title.replace(/[。！？；;:：,.，、]+$/g, '').trim()
    if (title.length > 14) {
      title = title.substring(0, 14)
    }
    return title.length > 0 ? title : '学习记录'
  }
  
  // 保存日记
  async saveNote(): Promise<void> {
    this.noteEditController.syncContent()

    // 修复：确保RichEditor内容已同步
    // 通过访问NoteEditView的onBeforeSave回调来强制同步
    // 注意：由于NoteEditView是子组件，我们无法直接访问其内部方法
    // 但我们可以通过触发一次内容变化来确保同步
    // 实际上，onContentChange会在内容变化时自动调用syncContentFromRichEditor
    // 所以这里我们只需要确保note对象的状态是最新的

    // 修复：在保存前，先尝试从RichEditor获取最新内容
    // 如果contentText为空，尝试从richEditorSpans提取
    // 注意：onBeforeSave 回调会在 NoteEditView 中自动调用 syncContentFromRichEditor
    // 但为了确保，我们在这里也做一次检查

    // 空笔记不写盘：title/正文/录音/清单/链接/媒体 全空就跳过保存
    if (this.isNoteEmpty()) {
      console.info('[DetailPage] 笔记为空，跳过保存')
      return
    }

    await this.ensureAutoTitle()
    this.note.title = this.titleText
    
    // 修复：确保content包含完整文本内容
    // 优先使用contentText，如果为空则从richEditorSpans中提取
    if (this.contentText && this.contentText.trim() !== '') {
      this.note.content = this.contentText
    } else if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
      try {
        const spanDataList: SpanData[] = JSON.parse(this.note.richEditorSpans) as SpanData[]
        let textContent = ''
        for (const spanData of spanDataList) {
          if (spanData.type === 'text' && spanData.value) {
            textContent += spanData.value
          }
        }
        if (textContent) {
          this.note.content = textContent
          this.contentText = textContent
          console.info('[DetailPage] 保存时从richEditorSpans提取文本，长度:', textContent.length)
        } else {
          console.warn('[DetailPage] richEditorSpans中没有文本内容')
        }
      } catch (e) {
        console.warn('[DetailPage] 从richEditorSpans提取文本失败:', e)
      }
    } else {
      // 如果都没有，至少保存空字符串
      this.note.content = this.contentText || ''
    }
    // Ensure lists are synced (crucial for rename/delete persistence)
    this.note.recordings = this.recordings
    this.note.checklist = this.checklistItems
    
    // 修复：确保链接已同步（NoteEditView会在syncContentFromRichEditor中同步，但我们需要确保）
    // 如果note.links不存在，从contentBlocks中恢复
    if (!this.note.links || this.note.links.length === 0) {
      if (this.note.contentBlocks) {
        const links: LinkItem[] = []
        this.note.contentBlocks.forEach(block => {
          if (block instanceof LinkBlock) {
            const linkItem = new LinkItem()
            linkItem.id = Date.now().toString() + Math.random().toString()
            linkItem.title = block.title
            linkItem.url = block.url
            links.push(linkItem)
          }
        })
        if (links.length > 0) {
          this.note.links = links
        }
      }
    }
    
    // 修复：确保richEditorSpans包含所有链接
    if (this.note.links && this.note.links.length > 0) {
      try {
        let spans: SpanData[] = []
        if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
          spans = JSON.parse(this.note.richEditorSpans) as SpanData[]
        }
        
        // 检查richEditorSpans中是否包含所有链接
        const linkUrlsInSpans = new Set(spans.filter(s => s.type === 'link' && s.linkUrl).map(s => s.linkUrl))
        let needUpdate = false
        
        for (const link of this.note.links) {
          if (!linkUrlsInSpans.has(link.url)) {
            spans.push({
              type: 'link',
              linkTitle: link.title,
              linkUrl: link.url
            })
            needUpdate = true
            console.info('[DetailPage] saveNote: 添加缺失的链接到richEditorSpans:', link.title)
          }
        }
        
        // 确保至少有一个文本span（如果没有文本内容但有链接）
        const hasText = spans.some(s => s.type === 'text' && s.value && s.value.trim() !== '')
        if (!hasText && spans.length > 0 && this.note.content && this.note.content.trim() !== '') {
          // 如果有内容但没有文本span，添加文本span
          spans.unshift({
            type: 'text',
            value: this.note.content
          })
          needUpdate = true
          console.info('[DetailPage] saveNote: 添加文本内容到richEditorSpans')
        }
        
        if (needUpdate) {
          this.note.richEditorSpans = JSON.stringify(spans)
          console.info('[DetailPage] saveNote: 更新richEditorSpans，包含', spans.length, '个元素')
        }
      } catch (e) {
        console.warn('[DetailPage] saveNote: 检查richEditorSpans失败:', e)
      }
    }
    
    // Sync emotion
    this.note.emotionLabel = this.selectedEmotionLabel
    this.note.emotionEmoji = this.selectedEmotionEmoji
    this.note.learningMoodLabel = this.selectedEmotionLabel
    this.note.learningMoodEmoji = this.selectedEmotionEmoji
    this.note.weatherLabel = this.selectedWeatherLabel
    this.note.weatherIcon = this.selectedWeatherIcon
    this.note.emotionColor = this.emotionColor
    // 问题4修复：同步分类
    this.note.category = this.selectedCategory
    this.note.locationName = this.locationName
    this.note.locationAddress = this.locationAddress
    this.note.latitude = this.latitude
    this.note.longitude = this.longitude
    
    // 修复：确保contentBlocks也同步（用于列表预览和恢复）
    if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
      try {
        const spanDataList: SpanData[] = JSON.parse(this.note.richEditorSpans) as SpanData[]
        const blocks: ContentBlock[] = []
        for (const spanData of spanDataList) {
          if (spanData.type === 'text' && spanData.value) {
            blocks.push(new TextBlock(spanData.value))
          } else if (spanData.type === 'image' && spanData.src) {
            blocks.push(new ImageBlock(spanData.src))
          } else if (spanData.type === 'video' && spanData.src) {
            blocks.push(new VideoBlock(spanData.src))
          } else if (spanData.type === 'link' && spanData.linkTitle && spanData.linkUrl) {
            blocks.push(new LinkBlock(spanData.linkTitle, spanData.linkUrl))
          }
        }
        this.note.contentBlocks = blocks
      } catch (e) {
        console.warn('[DetailPage] 构建contentBlocks失败:', e)
      }
    }

    this.syncMediaMetadataBeforeSave()
    
    this.note.lastModifiedTime = Date.now()
    
    // 修复：保存前最后一次检查，确保note.content被设置
    if (!this.note.content || this.note.content.trim() === '') {
      if (this.contentText && this.contentText.trim() !== '') {
        this.note.content = this.contentText
        console.info('[DetailPage] 保存前修复：从contentText设置note.content，长度:', this.contentText.length)
      } else if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
        try {
          const spanDataList: SpanData[] = JSON.parse(this.note.richEditorSpans) as SpanData[]
          let textContent = ''
          for (const spanData of spanDataList) {
            if (spanData.type === 'text' && spanData.value) {
              textContent += spanData.value
            }
          }
          if (textContent) {
            this.note.content = textContent
            this.contentText = textContent
            console.info('[DetailPage] 保存前修复：从richEditorSpans设置note.content，长度:', textContent.length)
          }
        } catch (e) {
          console.warn('[DetailPage] 保存前从richEditorSpans提取文本失败:', e)
        }
      }
    }
    
    // 修复：保存前打印详细信息
    console.info('[DetailPage] 准备保存，标题:', this.note.title, 'content长度:', this.note.content?.length || 0, 'contentText长度:', this.contentText?.length || 0, 'richEditorSpans长度:', this.note.richEditorSpans?.length || 0, 'richEditorSpans内容:', this.note.richEditorSpans?.substring(0, 200))
    
    await PreferencesUtil.saveNote(this.context, this.note)
    // 触发日记更新信号
    AppStorage.setOrCreate('diaryUpdatedAt', Date.now())
    
    console.info('[DetailPage] 保存完成，标题:', this.note.title, '内容长度:', this.note.content?.length || 0, '链接数:', this.note.links?.length || 0, 'richEditorSpans长度:', this.note.richEditorSpans?.length || 0, 'contentBlocks数量:', this.note.contentBlocks?.length || 0)
  }
  
  // 问题4修复：分类变更时自动同步到note对象
  onCategoryChange(): void {
    if (this.note && this.selectedCategory) {
      this.note.category = this.selectedCategory
    }
  }
  
  // 自动保存（防抖）
  debouncedSave(): void {
     if (this.saveTimer) clearTimeout(this.saveTimer)
     this.saveTimer = setTimeout(() => {
        this.saveNote()
     }, 1000)
  }


  // AI功能：智能分析日记内容并生成建议
  async performAIAnalysis(): Promise<void> {
    if (!this.contentText || this.contentText.length < 5) {
       promptAction.showToast({ message: '记录内容太少啦，多写一点吧~' })
       return
    }
    
    promptAction.showToast({ message: 'AI正在分析你的记录...' })

    try {
      const intentVM = IntentViewModel.getInstance()
      const currentDiaryId = this.note.id || `temp_${Date.now()}`

      const result: DiaryAnalysisResult = await intentVM.analyzeDiaryForConfirmation(this.contentText, currentDiaryId)

      // 显示鼓励语
      const encouragement = result.encouragement || '记录每一个当下，成就更好的自己 💪'
      promptAction.showToast({
        message: `💡 ${encouragement}`,
        duration: 3000
      })

      // 保存关键词
      if (result.keywords && result.keywords.length > 0) {
        await intentVM.autoSaveKeywords(this.contentText)
      }

      // 触发情绪分析更新 UI
      if (result.emotion && !this.selectedEmotionLabel) {
        this.triggerEmotionAnalysis()
      }

    } catch (err) {
      console.error('[DetailPage] AI智能分析失败:', err)
      promptAction.showToast({
        message: '大脑有点累，稍后再试吧~',
        duration: 2000
      })
    }
  }
  
  // 情绪分析触发
  triggerEmotionAnalysis(): void {
     if (this.emotionAnalysisTimer) clearTimeout(this.emotionAnalysisTimer)
     this.emotionAnalysisTimer = setTimeout(() => { this.analyzeEmotion() }, 1000)
  }
  
  async analyzeEmotion(): Promise<void> {
     if (!this.contentText || this.contentText.length < 5) return
     this.isEmotionAnalyzing = true
     this.emotionStatusText = '正在分析...'
     try {
        const result = await this.emotionAnalyzer.analyze(this.contentText)
        if (result) {
           this.applyEmotionResult(result)
        }
     } catch(e) {
        this.emotionStatusText = '分析失败'
     } finally {
        this.isEmotionAnalyzing = false
     }
  }
  
  applyEmotionResult(result: EmotionAnalysisResult): void {
     this.selectedEmotionLabel = result.emotionLabel
     this.selectedEmotionEmoji = result.emotionEmoji
     this.selectedWeatherLabel = result.weatherLabel
     this.selectedWeatherIcon = result.weatherIcon
     this.emotionColor = result.colorHex
     this.emotionConfidence = result.confidence
     this.emotionStatusText = `情绪：${result.emotionLabel}`
     this.saveNote() // 结果可以立即保存
  }

  // ==================== 菜单逻辑 ====================
  
  // 打开分类选择器(问题13修复)
  handleCategoryAction(): void {
    this.showCategoryPicker = true
  }

  // ==================== 锁逻辑 (直接交互) ====================

  handleLockAction(): void {
    if (this.note.isLocked) {
       // 已锁定 -> 提示解锁
       promptAction.showDialog({
         title: '解除锁定',
         message: '确定要移除记录密码吗？',
         buttons: [
           { text: '取消', color: AppColors.TEXT_SECONDARY },
           { text: '移除', color: AppColors.ERROR }
         ]
       }).then((dialogRes) => {
         if (dialogRes.index === 1) {
           this.note.isLocked = false
           this.note.password = ''
           this.saveNote()
           promptAction.showToast({ message: '已解除锁定' })
         }
       })
    } else {
       // 未锁定 -> 设置密码
       this.passwordInput = ''
       this.confirmPasswordInput = ''
       this.showLockDialog = true
    }
  }

  // ==================== 插入逻辑 ====================
  
  // 复制文件到沙箱以持久保存
  private async copyMediaToSandbox(sourceUri: string, type: 'image' | 'video'): Promise<string | null> {
    try {
      const filesDir = this.context.filesDir
      const timestamp = Date.now()
      const extension = type === 'image' ? 'jpg' : 'mp4' 
      
      const fileName = `${type}_${timestamp}_${Math.random().toString(36).substr(2, 6)}.${extension}`
      const destPath = `${filesDir}/${fileName}`
      
      const sourceFile = fs.openSync(sourceUri, fs.OpenMode.READ_ONLY)
      const destFile = fs.openSync(destPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
      
      fs.copyFileSync(sourceFile.fd, destFile.fd)
      
      fs.closeSync(sourceFile)
      fs.closeSync(destFile)
      
      const sandboxUri = fileUri.getUriFromPath(destPath)
      console.info('Media copied to sandbox:', sandboxUri)
      return sandboxUri
    } catch(e) {
      console.error('Copy to sandbox failed:', e)
      return sourceUri // Fallback to original
    }
  }

  async insertImageFromGallery(): Promise<void> {
     try {
       const slider = new photoAccessHelper.PhotoViewPicker()
       const result = await slider.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE, maxSelectNumber: 1 })
       if (result.photoUris.length > 0) {
          let uri = result.photoUris[0]
          const sandboxUri = await this.copyMediaToSandbox(uri, 'image')
          if (sandboxUri) uri = sandboxUri
          this.noteEditController.insertImage(uri)
       }
     } catch (e) {
       console.error('Insert Image failed', e)
     }
     this.showInsertMenu = false
  }
  
  async insertVideoFromGallery(): Promise<void> {
     try {
       const slider = new photoAccessHelper.PhotoViewPicker()
       const result = await slider.select({ MIMEType: photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE, maxSelectNumber: 1 })
       if (result.photoUris.length > 0) {
          let uri = result.photoUris[0]
          const sandboxUri = await this.copyMediaToSandbox(uri, 'video')
          if (sandboxUri) uri = sandboxUri
          this.noteEditController.insertVideo(uri)
       }
     } catch (e) { console.error(e) }
     this.showInsertMenu = false
  }

  async capturePhotoAndInsert(): Promise<void> {
     try {
       const captured: CapturedMedia | null = await MediaCaptureService.capturePhoto(this.context)
       if (captured && captured.uri) {
          this.noteEditController.insertImage(captured.uri)
       }
     } catch (e) {
       console.error('Capture photo failed', e)
       promptAction.showToast({ message: '拍照失败，请稍后重试', duration: 1500 })
     }
     this.showInsertMenu = false
  }

  private confirmInsertLink(): void {
    if (!this.showLinkDialog) {
      return
    }
    const url = this.tempLinkUrl.trim()
    if (url.length === 0) {
      promptAction.showToast({ message: '请输入链接地址', duration: 1200 })
      return
    }
    const title = this.tempLinkTitle.trim().length > 0 ? this.tempLinkTitle.trim() : url
    this.showLinkDialog = false
    this.tempLinkTitle = ''
    this.tempLinkUrl = ''
    this.noteEditController.insertLink(title, url)
    promptAction.showToast({ message: '链接已插入', duration: 1200 })
    this.saveNote()
  }

  private confirmInsertChecklist(): void {
    if (!this.showChecklistDialog) {
      return
    }
    const items = this.checklistInput.split('\n').map((item: string) => item.trim()).filter((item: string) => item.length > 0)
    if (items.length === 0) {
      promptAction.showToast({ message: '请输入清单内容', duration: 1200 })
      return
    }
    this.showChecklistDialog = false
    this.checklistInput = ''
    items.forEach((item: string) => this.noteEditController.insertChecklist(item))
    promptAction.showToast({ message: `已添加 ${items.length} 项清单`, duration: 1200 })
    this.saveNote()
  }

  // AI 智能标签建议：监听 contentText 变化，防抖 2s 后调 AI
  onContentTextChanged(): void {
    if (this.tagDebounceTimer !== -1) {
      clearTimeout(this.tagDebounceTimer)
      this.tagDebounceTimer = -1
    }
    const text = this.contentText.trim()
    if (text.length < 30) {
      this.suggestedTags = []
      return
    }
    // 长度变化太小不重新分析
    if (Math.abs(text.length - this.lastAnalyzedTagsLen) < 20) {
      return
    }
    this.tagDebounceTimer = setTimeout(() => {
      this.analyzeTags()
      this.tagDebounceTimer = -1
    }, 2000) as number
  }

  private async analyzeTags(): Promise<void> {
    const text = this.contentText.trim()
    if (text.length < 30) return
    this.isAnalyzingTags = true
    this.lastAnalyzedTagsLen = text.length
    const systemPrompt = `从下面 6 个固定分类中，按相关度从高到低挑选 3 个最适合内容的分类：${DEFAULT_LEARNING_CATEGORIES.join('、')}。
严格返回 JSON，不要任何其他文字：
{"tags":["分类1","分类2","分类3"]}`
    try {
      const response = await LongCatService.getInstance().chatLite(text.substring(0, 800), systemPrompt, true)
      const json = JSON.parse(response) as Record<string, Object>
      const rawTags = (json['tags'] as string[]) || []
      this.suggestedTags = rawTags.filter(t => DEFAULT_LEARNING_CATEGORIES.includes(t)).slice(0, 3)
    } catch (e) {
      console.warn('[DetailPage] analyzeTags failed:', e)
      this.suggestedTags = []
    }
    this.isAnalyzingTags = false
  }

  applySuggestedTag(tag: string): void {
    this.selectedCategory = tag
    this.suggestedTags = []
  }

  private autoCaptureLearningLocation(): void {
    if ((this.note.isLocked && !this.isPreUnlocked) || this.hasAutoRequestedLocation ||
      this.locationName.length > 0 || this.locationStatus === 'fetching') {
      return
    }
    this.hasAutoRequestedLocation = true
    this.addOrUpdateLearningLocation()
  }

  async addOrUpdateLearningLocation(): Promise<void> {
    this.locationStatus = 'fetching'
    this.locationStatusMessage = '正在定位...'
    const context = getContext(this) as common.Context
    const noteId = this.note.id

    // 后台定位：页面退出后仍会继续，完成后直接写入存储
    LocationService.fetchAndSaveInBackground(context, noteId, (location) => {
      // 页面还在时更新 UI
      this.locationName = location.locationName || '当前位置'
      this.locationAddress = location.locationAddress || ''
      this.latitude = location.latitude
      this.longitude = location.longitude
      this.locationStatus = 'success'
      this.locationStatusMessage = `已添加：${this.locationName}`
      setTimeout(() => {
        this.locationStatus = ''
        this.locationStatusMessage = ''
      }, 2200)
    })

    // 立即给个乐观反馈，不阻塞页面
    setTimeout(() => {
      if (this.locationStatus === 'fetching') {
        this.locationStatusMessage = '仍在定位中...'
      }
    }, 5000)
  }

  async deleteLearningLocation(): Promise<void> {
    this.locationName = ''
    this.locationAddress = ''
    this.latitude = 0
    this.longitude = 0
    await this.saveNote()
    this.locationStatus = 'success'
    this.locationStatusMessage = '已移除学习地点'
    setTimeout(() => {
      this.locationStatus = ''
      this.locationStatusMessage = ''
    }, 1500)
  }

  // ==================== 录音逻辑 ====================

  startRecording(): void {
    if (this.isRecording || this.isProcessing) return
    this.isProcessing = true
    this.realTimeTranscription = ''

    try {
    // 每次开始录音重置已上屏长度
      this.lastASRLength = 0
      
      this.recordingService.startRecording({
        onResult: (text: string, isFinal: boolean) => {
          // 【实时插入】计算新增的文字部分
          const currentLen = text.length
          const newPart = text.substring(this.lastASRLength)
          
          // 只要有新增内容就直接插入到日记，不等 isFinal
          if (newPart.length > 0) {
            this.noteEditController.insertText(newPart)
            this.lastASRLength = currentLen
          }
          
          // 更新预览（显示最近识别的内容）
          this.realTimeTranscription = isFinal ? '' : newPart
        },
        onVolumeChange: (level: number) => {
           this.currentVolume = level
        },
        onError: (code: number, message: string) => {
          console.error(`Recording error: ${code} - ${message}`)
          this.isRecording = false
          this.isProcessing = false
          promptAction.showToast({ message: '录音失败: ' + message })
        }
      })
      this.isRecording = true
      this.isProcessing = false
      this.recordingSeconds = 0
      
      this.startUITimer()
      this.startRippleAnimation()
      
    } catch (e) {
      console.error('Failed to start recording:', e)
      promptAction.showToast({ message: '启动录音失败' })
      this.isProcessing = false
    }
  }
  
  async stopRecording(): Promise<void> {
    if (!this.isRecording) return
    
    // 停止动画和计时器
    this.stopRippleAnimation()
    this.stopUITimer()
    
    this.isProcessing = true
    try {
      const recording = await this.recordingService.stopRecording()
      this.onRecordingComplete(recording)
    } catch (e) {
      console.error('Stop recording failed', e)
    } finally {
      this.isRecording = false
      this.isProcessing = false
      this.showRecordingOverlay = false 
    }
  }
  
  cancelRecording(): void {
     this.recordingService.cancelRecording()
     this.isRecording = false
     this.showRecordingOverlay = false
     this.stopRippleAnimation() 
     this.stopUITimer() 
     this.isProcessing = false 
  }
  
  onRecordingComplete(item: RecordingItem): void {
     // 强制使用24小时制命名
     const now = new Date()
     const pad = (n: number) => n.toString().padStart(2, '0')
     const name = `录音_${now.getFullYear()}${pad(now.getMonth()+1)}${pad(now.getDate())}_${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`
     item.name = name

     this.recordings = [...this.recordings, item]
     this.note.recordings = this.recordings
     
     // 补全剩余未上屏的文本
     const finalFullText = item.transcription || ''
     if (finalFullText.length > this.lastASRLength) {
         const remain = finalFullText.substring(this.lastASRLength)
         this.noteEditController.insertText(remain)
     }
     this.realTimeTranscription = ''
     
     this.saveNote()
     this.isProcessing = false 
  }
  
  // UI 计时器 (取代原有的 waveAnimationTimer) // Added
  startUITimer(): void {
     this.uiTimer = setInterval(() => {
        this.recordingSeconds++
        // Update waveHeights for the overlay if it were still active, or for other UI elements
        this.waveHeights = this.waveHeights.map(() => Math.random() * 40 + 10)
     }, 1000)
  }
  
  stopUITimer(): void {
     if (this.uiTimer) clearInterval(this.uiTimer)
     this.recordingSeconds = 0
  }
  
  // ==================== 波纹动画逻辑 ==================== // Added

  /** 启动波纹动画 */
  private startRippleAnimation() {
    if (this.rippleAnimationTimer) clearInterval(this.rippleAnimationTimer)
    this.ripples = []
    this.frameCount = 0
    this.rippleAnimationTimer = setInterval(() => {
      if (this.isRecording) {
        this.frameCount++
        this.updateRipples()
        this.drawRipples()
      }
    }, 16)
  }

  /** 停止波纹动画 */
  private stopRippleAnimation() {
    if (this.rippleAnimationTimer) {
      clearInterval(this.rippleAnimationTimer)
      this.rippleAnimationTimer = 0
    }
    this.ripples = []
    // 清空画布
    this.waveCanvasContext.clearRect(0, 0, 120, 120)
  }

  /**
   * 更新波纹状态 - 核心动画逻辑（与backup版本一致）
   * 根据音量动态生成和更新波纹
   */
  private updateRipples() {
    const now = Date.now()
    const centerRadius = 28  // 按钮半径
    const maxRadius = 58     // 最大扩散半径
    const volume = this.currentVolume

    // ===== 根据音量生成新波纹 =====
    if (volume > 3) {
      // 音量越大，波纹生成越频繁（间隔 60ms ~ 200ms）
      const interval = Math.max(60, 200 - volume * 1.4)

      if (now - this.lastRippleTime > interval) {
        // 波纹初始线宽与音量相关（1.5 ~ 4）
        const lineWidth = 1.5 + (volume / 100) * 2.5
        // 波纹扩散速度与音量相关（0.6 ~ 1.8）
        const speed = 0.6 + (volume / 100) * 1.2

        this.ripples.push({
          radius: centerRadius + 2,
          opacity: 0.7 + (volume / 100) * 0.3, // 初始透明度 0.7 ~ 1.0
          speed: speed,
          lineWidth: lineWidth
        })
        this.lastRippleTime = now
      }
    }

    // ===== 更新所有波纹 =====
    for (let i = this.ripples.length - 1; i >= 0; i--) {
      const ripple = this.ripples[i]

      // 扩散
      ripple.radius += ripple.speed

      // 透明度：随半径增大平滑衰减
      const progress = (ripple.radius - centerRadius) / (maxRadius - centerRadius)
      ripple.opacity = Math.max(0, (1 - progress * progress) * 0.8)

      // 线宽：随扩散逐渐变细
      ripple.lineWidth = Math.max(0.5, ripple.lineWidth * 0.98)

      // 移除消失的波纹
      if (ripple.radius > maxRadius || ripple.opacity <= 0.02) {
        this.ripples.splice(i, 1)
      }
    }
  }

  /**
   * 绘制波纹 - Canvas 渲染（与backup版本一致）
   * 包含扩散波纹和呼吸光晕两种效果
   */
  private drawRipples() {
    const ctx = this.waveCanvasContext
    const size = 120
    const cx = size / 2
    const cy = size / 2
    const volume = this.currentVolume
    
    // 清空画布
    ctx.clearRect(0, 0, size, size)
    
    // ===== 绘制扩散的波纹（一缕一缕） =====
    for (const ripple of this.ripples) {
      ctx.beginPath()
      ctx.arc(cx, cy, ripple.radius, 0, Math.PI * 2)
      ctx.closePath()
      
      // 红色渐变，外层偏橙（与录音按钮颜色协调）
      const r = Math.floor(220 + (ripple.radius / 60) * 35)
      const g = Math.floor(38 + (ripple.radius / 60) * 40)
      const b = 38
      ctx.strokeStyle = `rgba(${Math.min(255, r)}, ${g}, ${b}, ${ripple.opacity})`
      ctx.lineWidth = ripple.lineWidth
      ctx.stroke()
    }
    
    // ===== 绘制呼吸光晕（随音量变化） =====
    const glowRadius = 28 + (volume / 100) * 8
    const glowOpacity = 0.15 + (volume / 100) * 0.25

    // 外层柔和光晕
    const glowGradient = ctx.createRadialGradient(cx, cy, 28, cx, cy, glowRadius + 10)
    glowGradient.addColorStop(0, `rgba(239, 68, 68, ${glowOpacity})`)
    glowGradient.addColorStop(1, 'rgba(239, 68, 68, 0)')
    ctx.beginPath()
    ctx.arc(cx, cy, glowRadius + 10, 0, Math.PI * 2)
    ctx.fillStyle = glowGradient
    ctx.fill()
  }
  
  // ==================== 播放逻辑 ====================
  
  playRecording(item: RecordingItem): void {
     if (this.currentPlayingId === item.id && this.isPlaying) {
        this.stopPlayback()
     } else {
        this.stopPlayback()
        this.audioPlayer.playAudio(item.audioPath)
        this.currentPlayingId = item.id
        this.isPlaying = true
        this.currentDuration = item.audioDuration
        
        // Timer for progress
        this.playbackTimer = setInterval(() => {
           this.playbackProgress++
           if (this.playbackProgress >= this.currentDuration) {
              this.stopPlayback()
           }
        }, 1000)
     }
  }
  
  deleteRecording(item: RecordingItem): void {
     this.recordings = this.recordings.filter(r => r.id !== item.id)
     this.note.recordings = this.recordings
     this.saveNote()
  }
  
  updateChecklistItem(item: ChecklistItem): void {
     this.note.checklist = this.checklistItems
     this.saveNote() 
  }
  
  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp)
    const timeStr = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
    return `${DiaryUtils.formatDate(timestamp)} ${timeStr}`
  }

  /** AI 智能标签建议条 */
  @Builder
  TagSuggestionBar() {
    Row({ space: 10 }) {
      IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 16, color: '#cc785c' })
      Text(this.isAnalyzingTags ? 'AI 分析中…' : 'AI 建议')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6c6a64')

      if (!this.isAnalyzingTags) {
        ForEach(this.suggestedTags, (tag: string) => {
          Text(tag)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.selectedCategory === tag ? '#ffffff' : '#cc785c')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(this.selectedCategory === tag ? '#cc785c' : '#f5f0e8')
            .borderRadius(20)
            .border({ width: 1, color: '#e6dfd8' })
            .onClick(() => this.applySuggestedTag(tag))
        })
      } else {
        LoadingProgress().width(16).height(16).color('#cc785c')
      }
      Blank()
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 8 })
  }

  /** 媒体选中工具条 — 缩小/放大/全屏/删除 */
  @Builder
  MediaActionBar() {
    Row({ space: 8 }) {
      // 缩小
      Column() {
        IconImage({ src: $r('app.media.icon_minus'), iconSize: 18, color: AppColors.TEXT_PRIMARY })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(22)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(() => {
        if (this.selectedMediaImage) this.noteEditController.resizeSelectedImage(-40)
        else if (this.selectedMediaVideo) this.noteEditController.resizeSelectedVideo(-40)
      })

      // 放大
      Column() {
        IconImage({ src: $r('app.media.icon_plus'), iconSize: 18, color: AppColors.TEXT_PRIMARY })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(22)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(() => {
        if (this.selectedMediaImage) this.noteEditController.resizeSelectedImage(40)
        else if (this.selectedMediaVideo) this.noteEditController.resizeSelectedVideo(40)
      })

      // 全屏
      Column() {
        IconImage({ src: $r('app.media.icon_expand'), iconSize: 18, color: AppColors.TEXT_PRIMARY })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(22)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(() => {
        const path = this.selectedMediaImage || this.selectedMediaVideo
        const type = this.selectedMediaImage ? 'image' : 'video'
        if (path) {
          router.pushUrl({
            url: 'diary/view/pages/MediaPreviewPage',
            params: { path, type }
          })
        }
      })

      // 删除
      Column() {
        IconImage({ src: $r('app.media.icon_delete'), iconSize: 18, color: AppColors.ERROR })
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(22)
      .backgroundColor(AppColors.BG_SECONDARY)
      .border({ width: 1, color: AppColors.BORDER })
      .onClick(() => {
        if (this.selectedMediaImage) this.noteEditController.removeSelectedImage()
        else if (this.selectedMediaVideo) this.noteEditController.removeSelectedVideo()
      })

      Blank()

      // 关闭工具条
      Text('完成')
        .fontSize(14)
        .fontColor(AppColors.ACCENT)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .onClick(() => {
          this.selectedMediaImage = ''
          this.selectedMediaVideo = ''
        })
    }
    .width('92%')
    .height(56)
    .padding({ left: 12, right: 6 })
    .backgroundColor(AppColors.BG_PRIMARY)
    .borderRadius(28)
    .border({ width: 1, color: AppColors.BORDER })
    .shadow(AppShadows.SHADOW_LG)
    .position({ y: '78%' })
    .margin({ left: '4%' })
  }

  /** 内联录音按钮 - 2025 Premium Design (问题6修复：正居中 + 音量波纹动画) */
  @Builder
  RecordButtonWithWave() {
      Column({ space: 6 }) {
        // 实时转写文本显示
        if (this.isRecording && this.realTimeTranscription.length > 0) {
          Text(this.realTimeTranscription)
            .fontSize(14)
            .fontColor(AppColors.TEXT_PRIMARY)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(12)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .animation({ duration: 100 })
        }
        
        // 录音时长
        if (this.isRecording) {
          Text(this.formatRecordingTime(this.recordingSeconds))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.ERROR)
        }
        
        // 按钮主体 - 确保居中
        Stack({ alignContent: Alignment.Center }) {
            // 【问题6修复】音量波纹画布 - 随音量变化的动态波纹
            if (this.isRecording) {
              Canvas(this.waveCanvasContext)
                .width(120)
                .height(120)
                .backgroundColor(Color.Transparent)
                .hitTestBehavior(HitTestMode.None)
                .onReady(() => {
                   // Canvas已初始化
                })
            }

            // 外圈脉冲动画 (录音时显示) - 第二层波纹
            if (this.isRecording) {
              Circle()
                .width(68)
                .height(68)
                .fill(Color.Transparent)
                .stroke(AppColors.ERROR)
                .strokeWidth(2)
                .scale({ x: this.pulseScale, y: this.pulseScale })
                .opacity(Math.max(0, 2 - this.pulseScale))
              
              // 第三层波纹 - 更大更淡
              Circle()
                .width(84)
                .height(84)
                .fill(Color.Transparent)
                .stroke(AppColors.ERROR)
                .strokeWidth(1)
                .scale({ x: this.pulseScale * 1.1, y: this.pulseScale * 1.1 })
                .opacity(Math.max(0, (2 - this.pulseScale) * 0.5))
            }

            // 主按钮
            Column() {
              if (this.isProcessing) {
                LoadingProgress().width(22).height(22).color(AppColors.TEXT_WHITE)
              } else if (this.isRecording) {
                // 停止图标 - 圆角方块
                Column().width(16).height(16).borderRadius(3).backgroundColor(AppColors.TEXT_WHITE)
              } else {
                // 麦克风图标 - 极简现代设计 🎙️
                Stack() {
                  Column().width(10).height(14).borderRadius(5).backgroundColor(AppColors.TEXT_WHITE).position({ x: 9, y: 0 })
                  Column().width(18).height(9).borderRadius({ bottomLeft: 9, bottomRight: 9 }).backgroundColor(Color.Transparent)
                    .border({ width: { left: 2, right: 2, bottom: 2 }, color: AppColors.TEXT_WHITE }).position({ x: 5, y: 8 })
                  Column().width(2).height(5).backgroundColor(AppColors.TEXT_WHITE).position({ x: 13, y: 17 })
                  Column().width(10).height(2).borderRadius(1).backgroundColor(AppColors.TEXT_WHITE).position({ x: 9, y: 22 })
                }.width(28).height(26)
              }
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .backgroundColor(this.isRecording ? AppColors.ERROR : AppColors.BG_DARK_SECONDARY)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .shadow(AppShadows.SHADOW_MD)
            // 【问题8修复】改为长按录音，松开停止
            .onTouch((e: TouchEvent) => {
               if (e.type === TouchType.Down) {
                  if (!this.isRecording && !this.isProcessing) {
                     this.recordStartY = e.touches[0].y
                     this.startRecording()
                     // 启动脉冲动画
                     this.pulseScale = 1
                     animateTo({ duration: 1000, iterations: -1, playMode: PlayMode.Alternate }, () => {
                        this.pulseScale = 1.4
                     })
                  }
               } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                  if (this.isRecording) {
                     this.stopRecording()
                     this.pulseScale = 1
                  }
               }
            })
        }
        .width(120)
        .height(120)
        
        Text(this.isRecording ? '松开停止' : '长按开始录音')
           .fontSize(11)
           .fontColor(AppColors.TEXT_TERTIARY)
      }
      // 【问题6修复】确保按钮正居中
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)
  }

  // 格式化录音时长
  private formatRecordingTime(seconds: number): string {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        // 主界面
        Column() {
          // 顶部安全区
          Column()
            .width('100%')
            .height(this.topSafeHeight)
            .backgroundColor(AppColors.BG_PRIMARY)
          
          DiaryTopBar({ 
            onSave: async () => await this.saveNote(), 
            onAIAnalysis: () => this.performAIAnalysis(),
            isLocked: this.note.isLocked,
            categoryLabel: this.selectedCategory,
            topSafeHeight: this.topSafeHeight,  // 问题5修复：传递安全区高度
            onLockAction: () => this.handleLockAction(),
            onCategoryAction: () => this.handleCategoryAction()
          })

          // Date and Info Row
          Row() {
            Text(this.formatDateTime(this.note.createTime))
               .fontSize(12)
               .fontColor(AppColors.TEXT_HINT)
            Blank()
            if (this.selectedEmotionLabel) {
               Text(`${this.selectedEmotionEmoji} ${this.selectedEmotionLabel}  ${this.selectedWeatherIcon} ${this.selectedWeatherLabel}`)
                 .fontSize(12)
                 .fontColor(AppColors.TEXT_HINT)
            }
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 4, bottom: 4 })

          LearningLocationRow({
            locationName: $locationName,
            locationAddress: $locationAddress,
            onAddOrUpdate: () => this.addOrUpdateLearningLocation(),
            onDelete: () => this.deleteLearningLocation()
          })
          .margin({ left: 24, right: 24, top: 6, bottom: 6 })

          // AI 智能标签建议（contentText > 30 字时出现）
          if (this.suggestedTags.length > 0 || this.isAnalyzingTags) {
            this.TagSuggestionBar()
          }

          NoteEditView({
            note: $note,
            titleText: $titleText,
            contentText: $contentText,
            recordings: $recordings,
            checklistItems: $checklistItems,
            currentPlayingId: $currentPlayingId,
            playbackProgress: $playbackProgress,
            canUndo: $canUndo,
            canRedo: $canRedo,
            controller: this.noteEditController,
            selectedImagePath: $selectedMediaImage,
            selectedVideoPath: $selectedMediaVideo,
            onEmotionAnalysisTrigger: () => this.triggerEmotionAnalysis(),
            onPlayRecording: (item: RecordingItem) => this.playRecording(item),
            onDeleteRecording: (item: RecordingItem) => this.deleteRecording(item),
            onChecklistItemUpdate: (item: ChecklistItem) => this.updateChecklistItem(item),
            onContentChange: () => this.debouncedSave(), // Auto-save trigger
            onEditorReady: () => {
              console.info('[DetailPage] onEditorReady回调触发，note.id:', this.note.id, 'contentText长度:', this.contentText?.length || 0, 'note.content长度:', this.note.content?.length || 0)
              
              // 修复：如果contentText有内容，延迟检查并确保内容被添加到编辑器
              // 因为RichEditor的initRichEditorContent可能在数据加载前执行
              setTimeout(() => {
                const hasContent = (this.contentText && this.contentText.trim() !== '') || (this.note.content && this.note.content.trim() !== '')
                if (hasContent && this.noteEditController) {
                  // 检查内容是否已经显示（通过检查contentText是否等于note.content）
                  // 如果note.content有值，尝试通过insertText强制添加
                  const textToAdd = this.contentText || this.note.content || ''
                  if (textToAdd && textToAdd.trim() !== '') {
                    console.info('[DetailPage] onEditorReady(延迟检查): 检测到内容，尝试强制添加到编辑器，长度:', textToAdd.length)
                    // 注意：这里不能直接用insertText，因为会追加内容，需要先清空
                    // 实际上initRichEditorContent应该已经处理了，这里只是作为保险
                    console.info('[DetailPage] onEditorReady(延迟检查): 内容应已通过initRichEditorContent初始化')
                  }
                }
              }, 500)  // 延迟500ms确保initRichEditorContent完成
              
              // 修复：编辑器准备好后，插入待插入的链接
              if (this.pendingLinkData && this.noteEditController && this.noteEditController.insertLink) {
                setTimeout(() => {
                  // 插入链接到编辑器
                  this.noteEditController.insertLink(this.pendingLinkData!.title, this.pendingLinkData!.url)
                  
                  // 确保链接已添加到note.links数组
                  if (!this.note.links) {
                    this.note.links = []
                  }
                  const linkExists = this.note.links.some(l => l.url === this.pendingLinkData!.url)
                  if (!linkExists) {
                    const linkItem = new LinkItem()
                    linkItem.id = Date.now().toString()
                    linkItem.title = this.pendingLinkData!.title
                    linkItem.url = this.pendingLinkData!.url
                    this.note.links.push(linkItem)
                  }
                  
                  // 清理pendingLinkData（先保存引用，然后清空）
                  const linkDataToSave = this.pendingLinkData
                  if (!linkDataToSave) {
                    console.warn('[DetailPage] pendingLinkData为空，无法保存链接')
                    return
                  }
                  this.pendingLinkData = null
                  
                  // 等待编辑器同步完成后保存，确保richEditorSpans包含链接
                  setTimeout(async () => {
                    // 再次确认richEditorSpans包含链接
                    try {
                      if (this.note.richEditorSpans && this.note.richEditorSpans !== '[]') {
                        const spans: SpanData[] = JSON.parse(this.note.richEditorSpans) as SpanData[]
                        const hasLink = spans.some(s => s.type === 'link' && s.linkUrl === linkDataToSave.url)
                        if (!hasLink) {
                          // 如果richEditorSpans中没有链接，手动添加
                          const newSpan: SpanData = {
                            type: 'link',
                            linkTitle: linkDataToSave.title,
                            linkUrl: linkDataToSave.url
                          }
                          spans.push(newSpan)
                          this.note.richEditorSpans = JSON.stringify(spans)
                          console.info('[DetailPage] 手动添加链接到richEditorSpans')
                        }
                      }
                    } catch (e) {
                      console.warn('[DetailPage] 检查richEditorSpans失败:', e)
                    }
                    
                    // 保存以确保链接被持久化
                    await this.saveNote()
                    console.info('[DetailPage] 链接插入后已保存，richEditorSpans长度:', this.note.richEditorSpans?.length || 0)
                  }, 500)  // 增加延迟确保编辑器同步完成
                }, 200)  // 增加初始延迟
              }
            },
            onBeforeSave: () => {
              // 修复：保存前强制同步RichEditor内容
              // 这个回调会在saveNote中被调用
              // NoteEditView 会自动调用 syncContentFromRichEditor
            }
          })
          .layoutWeight(1)

          DiaryBottomBar({
            showInsertMenu: $showInsertMenu,
            showEmotionPanel: $showEmotionPanel,
            canUndo: this.canUndo,
            canRedo: this.canRedo,
            emotionEmoji: this.selectedEmotionEmoji,
            emotionLabel: this.selectedEmotionLabel,
            onUndo: () => this.noteEditController.undo(),
            onRedo: () => this.noteEditController.redo(),
            onRecord: () => this.startRecording(), // Modified
            centerButton: () => { this.RecordButtonWithWave() }
          })
        }
        .width('100%')
        .height('100%')

        // 媒体选中工具条（浮在底部，位于 DiaryBottomBar 上方）
        if (this.selectedMediaImage.length > 0 || this.selectedMediaVideo.length > 0) {
          this.MediaActionBar()
        }

        // 学习地点状态横幅
        if (this.locationStatus.length > 0) {
          Row({ space: 6 }) {
            if (this.locationStatus === 'fetching') {
              LoadingProgress().width(12).height(12).color(AppColors.TEXT_WHITE)
            } else {
              IconImage({
                src: this.locationStatus === 'error' ? $r('app.media.icon_close') : $r('app.media.icon_pin'),
                iconSize: 12,
                color: AppColors.TEXT_WHITE
              })
            }
            Text(this.locationStatusMessage)
              .fontSize(12)
              .fontColor(AppColors.TEXT_WHITE)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(VerticalAlign.Center)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.locationStatus === 'error' ? '#E53935'
            : this.locationStatus === 'success' ? '#16A34A'
            : '#1F2937')
          .borderRadius(8)
          .position({ x: '4%', y: this.topSafeHeight + 56 + 4 })
          .width('92%')
          .opacity(0.95)
        }

        // ========== 各种弹窗覆盖层 ==========
        // 注：CategoryPickerDialog已在下方正确位置使用$selectedCategory
        
        if (this.showLockDialog) {
           LockDialog({ 
             showDialog: $showLockDialog, 
             passwordInput: $passwordInput,
             confirmPasswordInput: $confirmPasswordInput,
             onConfirm: () => {
                if (this.passwordInput === this.confirmPasswordInput && this.passwordInput.length >= 4) {
                   this.note.password = this.passwordInput
                   this.note.isLocked = true
                   this.showLockDialog = false
                   this.saveNote()
                } else {
                   promptAction.showToast({ message: '密码不一致或太短' })
                }
             }
           })
        }
        
        if (this.showUnlockDialog) {
           UnlockDialog({
             showDialog: $showUnlockDialog,
             passwordInput: $passwordInput,
             onUnlock: () => {
                if (this.passwordInput === this.note.password) {
                   this.showUnlockDialog = false
                   this.isPreUnlocked = true
                   this.autoCaptureLearningLocation()
                } else {
                   promptAction.showToast({ message: '密码错误' })
                }
             }
           })
        }
        
        // 问题4修复：使用独立的selectedCategory状态变量
        if (this.showCategoryPicker) {
           CategoryPickerDialog({
             showDialog: $showCategoryPicker,
             category: $selectedCategory,
             categories: this.categories
           })
        }
        
        if (this.showInsertMenu) {
           InsertMenuDialog({
             showMenu: $showInsertMenu,
             showLinkDialog: $showLinkDialog,
             showChecklistDialog: $showChecklistDialog,
             onInsertImage: () => this.insertImageFromGallery(),
             onInsertVideo: () => this.insertVideoFromGallery(),
             onCapturePhoto: () => this.capturePhotoAndInsert()
           })
        }
        
        if (this.showLinkDialog) {
           LinkDialog({
             showDialog: $showLinkDialog,
             title: $tempLinkTitle,
             url: $tempLinkUrl,
             onConfirm: () => this.confirmInsertLink()
           })
        }
        
        if (this.showChecklistDialog) {
           ChecklistDialog({
              showDialog: $showChecklistDialog,
              input: $checklistInput,
              onConfirm: () => this.confirmInsertChecklist()
           })
        }
        
        if (this.showEmotionPanel) {
           Stack({ alignContent: Alignment.Bottom }) {
              Column()
                .width('100%')
                .height('100%')
                .backgroundColor('#00000040')
                .onClick(() => this.showEmotionPanel = false)
                
              EmotionPanel({
                 showPanel: $showEmotionPanel,
                 isAnalyzing: this.isEmotionAnalyzing,
                 statusText: this.emotionStatusText,
                 selectedEmoji: this.selectedEmotionEmoji,
                 selectedLabel: this.selectedEmotionLabel,
                 selectedKey: this.selectedEmotionKey,
                 weatherIcon: this.selectedWeatherIcon,
                 weatherLabel: this.selectedWeatherLabel,
                 themeColor: this.emotionColor,
                 errorText: this.emotionAnalysisError,
                 onRetry: () => this.analyzeEmotion(),
                 onSelectPreset: (preset: EmotionPreset) => {
                    const result: EmotionAnalysisResult = { 
                       emotionLabel: preset.label,
                       emotionEmoji: preset.emoji,
                       weatherLabel: preset.weather,
                       weatherIcon: preset.weatherIcon,
                       colorHex: preset.color,
                       confidence: 1,
                       emotionKey: preset.key
                    }
                    this.applyEmotionResult(result)
                 }
              })
           }
           .zIndex(900)
        }
        
        // 录音覆盖层不再需要，已改为内联 // Modified
        // if (this.showRecordingOverlay) {
        //    AudioRecordingOverlay({
        //       isRecording: $isRecording,
        //       recordingSeconds: $recordingSeconds,
        //       waveHeights: this.waveHeights,
        //       transcriptionText: this.realTimeTranscription,
        //       onStop: () => this.stopRecording(),
        //       onCancel: () => this.cancelRecording()
        //    })
        // }

        // 全局"问问 AI"悬浮按钮（编辑笔记时随手问）
        Column() {
          GlobalAskAIFab({ bottomOffset: this.bottomSafeHeight + 130 })
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.End)
        .justifyContent(FlexAlign.End)
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .hideTitleBar(true)
  }
}
