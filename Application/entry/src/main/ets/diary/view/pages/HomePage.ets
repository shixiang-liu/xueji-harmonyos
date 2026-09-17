/**
 * @file HomePage.ets
 * @description 应用主页 - 日记列表展示、录音创建、分类管理
 * @features 侧边栏导航、搜索筛选、长按录音、语音识别
 * @version 2.0.0 - 2025 Premium Design
 */

import { router, promptAction } from '@kit.ArkUI'
import { preferences } from '@kit.ArkData'
import common from '@ohos.app.ability.common'
import window from '@ohos.window'
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl'
import { NoteItem } from '../../../diary/model/NoteItem'
import { RecordingItem } from '../../../diary/model/RecordingItem'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { AudioRecorder } from '../../../common/utils/AudioRecorder'
import { AppColors, AppSizes, AppShadows, AppAnimations } from '../../../common/utils/AppTheme'
import { speechRecognizer } from '@kit.CoreSpeechKit'
import { VoiceWaveCanvas, VoiceWaveBars } from '../../../common/components/VoiceWaveCanvas'
import { CloudDiaryService } from '../../../common/services/CloudDiaryService'
import { LearningRecordCard } from '../components/LearningRecordCard'
import { DEFAULT_LEARNING_CATEGORIES, normalizeLearningCategory } from '../../utils/LearningCategories'
import { IconImage } from '../../../common/components/IconImage'
import { buildLearningDaySummary, LearningDaySummary } from '../../utils/LearningDaySummary'
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab'
import { ProfileSheet } from '../components/ProfileSheet'
import { AvatarStore, AVATAR_PRESETS } from '../../../common/services/AvatarStore'

/** 默认分类列表 */
const DEFAULT_CATEGORIES: string[] = DEFAULT_LEARNING_CATEGORIES

@Entry
@Component
export struct VoiceDiaryHome {
  // ==================== 状态变量 ====================

  /** 日记列表 */
  @State noteList: NoteItem[] = []

  /** 搜索关键词 */
  @State searchText: string = ''

  /** 当前选中的Tab索引 */
  @State selectedTab: number = 0

  /** 加载状态 */
  @State isLoading: boolean = true

  // ---------- 录音相关状态 ----------

  /** 是否正在录音 */
  @State isRecording: boolean = false

  /** 是否正在处理（保存中） */
  @State isProcessing: boolean = false

  /** 录音时长（秒） */
  @State recordingSeconds: number = 0

  /** 录音按钮缩放比例 */
  @State recordButtonScale: number = 1

  /** 波纹动画缩放比例 */
  @State waveScale: number = 1

  /** 是否显示录音浮层 */
  @State showRecordingOverlay: boolean = false

  /** 实时识别文本 */
  @State recognizedText: string = ''

  /** 累积识别文本 */
  @State accumulatedText: string = ''

  /** 是否正在识别 */
  @State isRecognizing: boolean = false

  /** 上一次ASR结果（用于断句检测） */
  @State lastAsrResult: string = ''

  /** 当前录音音量 (0-100) */
  @State currentVolume: number = 0

  /** 上滑取消 - 触摸起始Y坐标 */
  @State touchStartY: number = 0

  /** 上滑取消 - 当前滑动偏移量 */
  @State dragOffsetY: number = 0

  /** 上滑取消 - 是否进入取消区域 */
  @State isInCancelZone: boolean = false

  /** 上滑取消阈值 (px) */
  private readonly CANCEL_THRESHOLD: number = 100

  // ---------- 布局相关状态 ----------

  /** 顶部安全区高度 */
  @State topSafeHeight: number = 0

  /** 底部安全区高度 */
  @State bottomSafeHeight: number = 0

  /** 当前按下的卡片ID */
  @State pressedCardId: string = ''

  /** 是否处于多选模式 */
  @State isMultiSelectMode: boolean = false

  /** 已选择的日记ID集合 */
  @State selectedNoteIds: string[] = []

  /** 分类列表（与内置 Tab 拼接展示） */
  @State categories: string[] = [...DEFAULT_CATEGORIES]

  // ---------- 对话框状态 ----------

  /** 是否显示解锁对话框 */
  @State showUnlockDialog: boolean = false

  /** 解锁密码输入 */
  @State unlockPasswordInput: string = ''

  /** 当前正在解锁的日记ID */
  @State currentUnlockingNoteId: string = ''

  /** 解锁后要执行的动作：open | delete */
  @State pendingUnlockAction: string = 'open'

  /** 解锁错误信息 */
  @State unlockError: string = ''
  
  /** 已验证密码的日记ID缓存（任务3.7：一次验证） */
  @State unlockedNoteIds: Set<string> = new Set()

  /** 是否显示新建文件夹对话框 */
  @State showNewFolderDialog: boolean = false

  /** 新文件夹名称 */
  @State newFolderName: string = ''

  /** 复盘入口卡片状态 */
  @State todayHasReflection: boolean = false
  @State todaySummary: LearningDaySummary = new LearningDaySummary()
  @StorageProp('pendingReflectionLaunch') @Watch('onPendingReflection') pendingReflectionLaunch: number = 0
  @StorageProp('currentUserAvatar') currentAvatarUri: string = ''
  @StorageProp('currentUserNickname') currentUserNickname: string = ''

  onPendingReflection(): void {
    if (this.pendingReflectionLaunch > 0) {
      // 重置避免重复触发
      AppStorage.setOrCreate('pendingReflectionLaunch', 0)
      router.pushUrl({ url: 'diary/view/pages/ReflectionPage' })
    }
  }

  /** 头像默认资源（根据预设值返回相应图片） */
  private currentAvatarResource(): Resource {
    const parsed = AvatarStore.parse(this.currentAvatarUri)
    if (parsed.kind === 'preset' && parsed.presetIdx >= 0 && parsed.presetIdx < AVATAR_PRESETS.length) {
      return AVATAR_PRESETS[parsed.presetIdx]
    }
    return AVATAR_PRESETS[0]
  }

  // ==================== 私有成员 ====================

  /** 语音识别引擎 */
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null

  /** ASR会话ID */
  private asrSessionId: string = ''

  /** 录音器实例 */
  private audioRecorder: AudioRecorder = new AudioRecorder()

  /** 录音计时器 */
  private recordingTimer: number = 0

  /** 波纹动画计时器 */
  private waveAnimTimer: number = 0

  /** Tab标签文本 */
  private tabs: string[] = ['全部', '最近', '语音', '收藏']
  // ==================== 生命周期 ====================

  // 修复：监听日记更新信号
  @StorageProp('diaryUpdatedAt') @Watch('onDiaryUpdated') diaryUpdatedAt: number = 0
  
  onDiaryUpdated(): void {
    console.info('[HomePage] 监听到日记更新，刷新列表')
    this.loadNotes()
  }

  /**
   * 组件即将显示
   * 初始化权限、服务、数据和全屏布局
   */
  async aboutToAppear(): Promise<void> {
    await this.requestPermissions()
    await this.initServices()
    await this.loadNotes()
    await this.setFullScreen()
  }
  
  /**
   * 组件即将销毁
   * 释放录音器资源
   */
  async aboutToDisappear(): Promise<void> {
    await this.audioRecorder.release()
  }

  /**
   * 请求应用所需权限
   * 如果权限被拒绝，提供设置引导
   */
  async requestPermissions(): Promise<void> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const permissions: Array<Permissions> = [
        'ohos.permission.MICROPHONE',
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION',
        'ohos.permission.READ_IMAGEVIDEO',
        'ohos.permission.WRITE_IMAGEVIDEO',
        'ohos.permission.INTERNET',
        'ohos.permission.GET_NETWORK_INFO'
      ]
      const context = getContext(this) as common.UIAbilityContext
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      
      // 检查麦克风权限是否被授予（录音核心功能）
      const micIndex = permissions.indexOf('ohos.permission.MICROPHONE')
      if (micIndex !== -1 && result.authResults[micIndex] !== 0) {
        // 权限被拒绝，显示引导提示
        promptAction.showDialog({
          title: '需要麦克风权限',
          message: '录音功能需要麦克风权限。请到系统设置 > 应用管理 > 学迹 > 权限 中开启麦克风权限。',
          buttons: [
            { text: '知道了', color: AppColors.ACCENT }
          ]
        })
        console.warn('[HomePage] 麦克风权限被拒绝')
      }
      
      console.info('[HomePage] 权限请求完成')
    } catch (e) {
      console.warn('[HomePage] 权限请求失败:', e)
    }
  }

  /** 初始化服务 */
  async initServices(): Promise<void> {
    try {
      await this.audioRecorder.init()
    } catch (e) {
      console.warn('[HomePage] 服务初始化失败:', e)
    }
  }

  /** 设置全屏布局 */
  async setFullScreen(): Promise<void> {
    try {
      const win = await window.getLastWindow(getContext(this))
      await win.setWindowLayoutFullScreen(true)
      const avoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      this.topSafeHeight = px2vp(avoidArea.topRect.height)
      this.bottomSafeHeight = px2vp(avoidArea.bottomRect.height)
    } catch (e) {
      this.topSafeHeight = 44
      this.bottomSafeHeight = 34
    }
  }

  /** 加载日记数据 */
  async loadNotes(): Promise<void> {
    try {
      const context = getContext() as common.Context
      const notes = await PreferencesUtil.loadNotes(context)
      this.noteList = notes.filter((n: NoteItem) => n && n.id)
      this.rebuildCategories(this.noteList)
      this.checkTodayReflection()
      this.rebuildTodaySummary()
      console.info('[HomePage] 加载日记数量:', this.noteList.length)
      this.isLoading = false
    } catch (e) {
      console.error('[HomePage] 加载日记失败:', e)
      this.noteList = []
      this.rebuildCategories(this.noteList)
      this.rebuildTodaySummary()
      this.isLoading = false
    }
  }

  /** 检查今天是否已经做过复盘 */
  private checkTodayReflection(): void {
    const today = new Date()
    const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
    this.todayHasReflection = this.noteList.some((n: NoteItem) =>
      n.noteType === 'reflection' && n.reflectionDate === todayStr
    )
  }

  private rebuildTodaySummary(): void {
    this.todaySummary = buildLearningDaySummary(this.noteList, Date.now())
  }

  /** 页面显示时刷新数据（修复：确保新建日记后能看到） */
  async onPageShow(): Promise<void> {
    console.info('[HomePage] 页面显示，刷新数据')
    // 修复：先刷新日记列表
    await this.loadNotes()

    try {
      // 检查是否有从回收站恢复的日记
      const restoredNote = AppStorage.get<NoteItem>('restoredNote')
      console.info('[HomePage] 检查恢复日记:', restoredNote ? restoredNote.id : '无')
      
      if (restoredNote && restoredNote.id) {
        // 先删除 AppStorage 中的数据
        AppStorage.delete('restoredNote')
        console.info('[HomePage] 已删除 AppStorage 中的恢复日记')
        
        // 将恢复的日记添加到列表
        const context = getContext() as common.Context
        const notes = await PreferencesUtil.loadNotes(context)
        
        // 检查是否已存在
        const exists = notes.some((n: NoteItem) => n.id === restoredNote.id)
        console.info('[HomePage] 日记是否已存在:', exists, '当前日记数:', notes.length)
        
        if (!exists) {
          // 确保日记的 deletedTime 为 0
          restoredNote.deletedTime = 0
          notes.unshift(restoredNote)
          await PreferencesUtil.saveNotes(context, notes)
          console.info('[HomePage] 恢复日记已保存，新日记数:', notes.length)
          promptAction.showToast({ message: '记录已恢复到列表', duration: 2000 })
        }
      }

      const context = getContext() as common.Context
      const newNotes = await PreferencesUtil.loadNotes(context)
      const filteredNotes = newNotes.filter((n: NoteItem) => n && n.id)

      this.noteList = []
      await new Promise<void>((resolve) => setTimeout(resolve, 20))
      this.noteList = filteredNotes
      console.info('[HomePage] 刷新完成，日记数量:', this.noteList.length)
      this.rebuildCategories(this.noteList)
      this.checkTodayReflection()
      this.rebuildTodaySummary()
    } catch (e) {
      console.error('[HomePage] 刷新数据失败:', e)
    }
  }

  /** 重建分类列表 */
  private rebuildCategories(notes: NoteItem[]): void {
    const categorySet = new Set<string>(DEFAULT_CATEGORIES)

    this.categories
      .filter((name: string) => name && !DEFAULT_CATEGORIES.includes(name))
      .forEach((name: string) => categorySet.add(name))

    notes.forEach((note: NoteItem) => {
      categorySet.add(this.normalizeCategoryName(note.category))
    })

    this.categories = Array.from(categorySet)
  }

  /** 规范化分类名称 */
  private normalizeCategoryName(value?: string): string {
    return normalizeLearningCategory(value)
  }

  /** 获取筛选后的日记列表 */
  getFilteredNotes(): NoteItem[] {
    let filtered = this.noteList

    // 搜索筛选
    if (this.searchText.trim()) {
      const kw = this.searchText.toLowerCase()
      filtered = filtered.filter((n: NoteItem) => this.noteMatchesSearch(n, kw))
    }

    // Tab筛选
    switch (this.selectedTab) {
      case 0: // 全部，无额外过滤
        break
      case 1: // 最近7天
        const weekAgo = Date.now() - 7 * 24 * 60 * 60 * 1000
        filtered = filtered.filter((n: NoteItem) => (n.createTime || 0) > weekAgo)
        break
      case 2: // 语音记录
        filtered = filtered.filter((n: NoteItem) => n.recordings && n.recordings.length > 0)
        break
      case 3: // 收藏
        filtered = filtered.filter((n: NoteItem) => n.isFavorite === true)
        break
      default: {
        // 分类筛选：selectedTab >= 4
        const catIdx = this.selectedTab - this.tabs.length
        if (catIdx >= 0 && catIdx < this.categories.length) {
          const targetCat = this.categories[catIdx]
          filtered = filtered.filter((n: NoteItem) => this.normalizeCategoryName(n.category) === targetCat)
        }
        break
      }
    }

    return filtered
  }

  private noteMatchesSearch(note: NoteItem, keyword: string): boolean {
    if (note.title && note.title.toLowerCase().includes(keyword)) {
      return true
    }
    if (note.content && note.content.toLowerCase().includes(keyword)) {
      return true
    }
    if (note.recordings) {
      for (let i = 0; i < note.recordings.length; i++) {
        const transcription = note.recordings[i].transcription || ''
        if (transcription.toLowerCase().includes(keyword)) {
          return true
        }
      }
    }
    return false
  }

  /** 格式化日期（简短） */
  formatDate(timestamp: number): string {
    if (!timestamp) return ''
    const d = new Date(timestamp)
    const now = new Date()
    if (d.toDateString() === now.toDateString()) {
      return `今天 ${d.getHours().toString().padStart(2, '0')}:${d.getMinutes().toString().padStart(2, '0')}`
    }
    return `${d.getMonth() + 1}月${d.getDate()}日`
  }

  // ==================== 录音功能 ====================

  /** 开始录音 */
  async startRecording(): Promise<void> {
    if (this.isProcessing || this.isRecording) return

    try {
      this.isRecording = true
      this.recordingSeconds = 0
      this.recognizedText = '正在初始化...'
      this.accumulatedText = ''
      this.isRecognizing = true
      this.showRecordingOverlay = true

      this.startRecordingAnimation()
      await this.initAsrEngine()

      // 启动录音并将音频数据发送给ASR，同时接收音量回调
      await this.audioRecorder.startRecording(
        // 音频数据回调 - 发送给 ASR
        (buffer: ArrayBuffer) => {
          if (this.asrEngine && this.asrSessionId) {
            const uint8Array = new Uint8Array(buffer)
            this.asrEngine.writeAudio(this.asrSessionId, uint8Array)
          }
        },
        // 音量回调 - 更新声波动画
        (volume: number) => {
          this.currentVolume = volume
        }
      )

      this.recognizedText = '正在聆听...'
      this.recordingTimer = setInterval(() => {
        this.recordingSeconds += 0.1
      }, 100)
    } catch (error) {
      console.error('[HomePage] 录音启动失败:', error)
      this.isRecording = false
      this.showRecordingOverlay = false
      this.stopRecordingAnimation()
      promptAction.showToast({ message: '录音失败', duration: 2000 })
    }
  }

  /** 初始化语音识别引擎 */
  async initAsrEngine(): Promise<void> {
    try {
      const extraParam: Record<string, Object> = {
        'locate': 'CN',
        'recognizerMode': 'long'
      }
      const params: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: extraParam
      }
      this.asrEngine = await speechRecognizer.createEngine(params)
      console.info('[HomePage] ASR引擎创建成功')

      this.asrEngine.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
          console.info('[HomePage] ASR识别启动')
          this.isRecognizing = true
          this.accumulatedText = ''
          this.lastAsrResult = ''
          this.recognizedText = '正在聆听...'
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
          console.info('[HomePage] ASR Event:', eventCode)
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          if (!result || typeof result.result !== 'string') return
          const newText = result.result
          const isFinal = result.isFinal
          
          if (isFinal) {
            if (newText.length > 0) {
              this.addTextWithPunctuation(newText, '。')
            }
            this.lastAsrResult = ''
            this.recognizedText = this.accumulatedText
            return
          }
          
          // 检测句子断开
          if (this.lastAsrResult.length > 0 && newText.length < this.lastAsrResult.length * 0.5) {
            this.addTextWithPunctuation(this.lastAsrResult, '、')
          }
          
          this.lastAsrResult = newText
          this.recognizedText = this.accumulatedText + newText
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          console.info('[HomePage] ASR 识别完成')
          if (this.lastAsrResult.length > 0) {
            this.addTextWithPunctuation(this.lastAsrResult, '。')
          }
          this.recognizedText = this.accumulatedText
          this.isRecognizing = false
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          console.error('[HomePage] ASR 错误:', errorCode, errorMessage)
          this.isRecognizing = false
        }
      })
      
      this.asrSessionId = `home_asr_${Date.now()}`
      this.isRecognizing = true

      const startParams: speechRecognizer.StartParams = {
        sessionId: this.asrSessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      }
      await this.asrEngine.startListening(startParams)
      console.info('[HomePage] ASR开始监听')
    } catch (e) {
      console.error('[HomePage] ASR初始化失败:', e)
    }
  }

  /** 添加文本并智能添加标点 */
  addTextWithPunctuation(text: string, defaultPunctuation: string): void {
    if (!text || text.length === 0) return
    text = text.trim()
    if (text.length === 0) return

    if (/[。！？、，,.!?]$/.test(text)) {
      this.accumulatedText += text
    } else {
      this.accumulatedText += text + defaultPunctuation
    }
  }

  /** 停止录音并保存 */
  async stopRecording(): Promise<void> {
    if (!this.isRecording) return

    this.isProcessing = true
    this.isRecording = false
    this.currentVolume = 0  // 重置音量
    this.stopRecordingAnimation()
    clearInterval(this.recordingTimer)

    try {
      // 停止语音识别
      if (this.asrEngine && this.asrSessionId) {
        try {
          this.asrEngine.finish(this.asrSessionId)
          this.asrEngine.shutdown()
        } catch (e) {
          console.warn('[HomePage] 停止ASR失败:', e)
        }
        this.asrEngine = null
        this.asrSessionId = ''
      }

      const audioPath = await this.audioRecorder.stopRecording()
      this.showRecordingOverlay = false

      // 录音时间过短（至少1秒才能有效识别）
      if (this.recordingSeconds < 1) {
        promptAction.showToast({ message: '录音时间太短', duration: 1500 })
        this.isProcessing = false
        this.recognizedText = ''
        this.accumulatedText = ''
        return
      }

      // 获取最终识别文字
      const finalText = this.accumulatedText || this.recognizedText || ''

      // 创建录音项
      const newRecording: RecordingItem = new RecordingItem()
      newRecording.id = `rec_${Date.now()}`
      newRecording.name = '录音'
      newRecording.audioPath = audioPath
      newRecording.audioDuration = this.recordingSeconds
      newRecording.createTime = Date.now()
      newRecording.transcription = finalText

      // 创建日记
      const newNote: NoteItem = new NoteItem()
      newNote.id = `note_${Date.now()}`
      newNote.title = finalText ? finalText.substring(0, 20) + (finalText.length > 20 ? '...' : '') : '语音记录'
      newNote.content = finalText
      newNote.createTime = Date.now()
      newNote.date = this.formatDate(Date.now())
      newNote.category = '课程'
      newNote.recordings = [newRecording]
      newNote.isFavorite = false

      // 保存日记
      const context = getContext() as common.Context
      const notes = await PreferencesUtil.loadNotes(context)
      notes.unshift(newNote)
      await PreferencesUtil.saveNotes(context, notes)

      this.noteList = notes
      
      // 清理状态
      this.recognizedText = ''
      this.accumulatedText = ''
      
      // 自动跳转到详情页继续编辑（任务3.6）
      router.pushUrl({
        url: 'diary/view/pages/DetailPage',
        params: { noteId: newNote.id }
      })
      promptAction.showToast({ message: '已创建，可继续编辑', duration: 1500 })
    } catch (error) {
      this.showRecordingOverlay = false
      promptAction.showToast({ message: '保存失败', duration: 2000 })
    } finally {
      this.isProcessing = false
      this.recordButtonScale = 1
      this.isRecognizing = false
    }
  }

  /** 启动录音波纹动画 */
  startRecordingAnimation(): void {
    this.waveAnimTimer = setInterval(() => {
      animateTo({ duration: 600, curve: Curve.EaseInOut }, () => {
        this.waveScale = this.waveScale === 1 ? 1.3 : 1
      })
    }, 600)
  }

  /** 停止录音波纹动画 */
  stopRecordingAnimation(): void {
    clearInterval(this.waveAnimTimer)
    this.waveScale = 1
  }

  // ==================== UI构建器 ====================

  /** 主界面布局 */
  build() {
    Stack() {
      Column() {
        // 顶部安全区
        Column().width('100%').height(this.topSafeHeight).backgroundColor(AppColors.BG_PRIMARY)

        this.HeaderSection()
        this.SearchSection()
        this.ReflectionEntryCard()
        this.TabsSection()
        this.MultiSelectToolbar()
        this.NoteListSection()

        // 底部安全区
        Column().width('100%').height(this.bottomSafeHeight + 100).backgroundColor(AppColors.BG_PRIMARY)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG_PRIMARY)

      // 录音按钮
      this.RecordingButton()

      // 解锁对话框
      if (this.showUnlockDialog) {
        this.UnlockDialog()
      }

      // 新建文件夹对话框
      if (this.showNewFolderDialog) {
        this.NewFolderDialog()
      }

      // 录音浮层
      if (this.showRecordingOverlay) {
        this.RecordingOverlay()
      }

      // 全局"问问 AI"悬浮按钮（右下角）
      Column() {
        GlobalAskAIFab({ bottomOffset: this.bottomSafeHeight + 110 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)

      // 个人中心底部抽屉
      ProfileSheet()
    }
    .width('100%')
    .height('100%')
  }

  /** 解锁对话框 */
  @Builder UnlockDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_DARK)
        .onClick(() => { this.showUnlockDialog = false })

      Column({ space: 16 }) {
        Column() {
          IconImage({ src: $r('app.media.icon_lock'), iconSize: 28, color: AppColors.TEXT_PRIMARY })
        }
        .width(56)
        .height(56)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(28)
        .backgroundColor(AppColors.BG_TERTIARY)
        .margin({ bottom: 8 })

        Text('此记录已开启隐私保护')
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)

        Text('请输入密码以查看内容')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_SECONDARY)

        TextInput({ text: this.unlockPasswordInput, placeholder: '输入密码' })
          .type(InputType.Password)
          .width('100%')
          .height(46)
          .fontSize(AppSizes.FONT_MD)
          .backgroundColor(AppColors.BG_SECONDARY)
          .borderRadius(AppSizes.RADIUS_SM)
          .border({ width: 1, color: this.unlockError ? AppColors.WARNING : AppColors.BORDER })
          .onChange((v: string) => {
            this.unlockPasswordInput = v
            this.unlockError = ''
          })

        if (this.unlockError) {
          Text(this.unlockError)
            .fontSize(AppSizes.FONT_XS)
            .fontColor(AppColors.WARNING)
        }

        Row({ space: 12 }) {
          Text('取消')
            .fontSize(AppSizes.FONT_MD)
            .fontColor(AppColors.TEXT_SECONDARY)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(AppSizes.RADIUS_SM)
            .border({ width: 1, color: AppColors.BORDER })
            .onClick(() => { this.showUnlockDialog = false })

          Text('确认')
            .fontSize(AppSizes.FONT_MD)
            .fontColor(AppColors.TEXT_WHITE)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(AppSizes.RADIUS_SM)
            .onClick(() => this.confirmUnlock())
        }
        .margin({ top: 8 })
      }
      .width('80%')
      .padding(24)
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius(AppSizes.RADIUS_LG)
      .shadow(AppShadows.SHADOW_LG)
    }
    .width('100%')
    .height('100%')
    .zIndex(1000)
  }

  // 新建文件夹对话框
  @Builder NewFolderDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(AppColors.OVERLAY_DARK)
        .onClick(() => { this.showNewFolderDialog = false })

      Column({ space: 16 }) {
        Text('新建分类')
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)

        TextInput({ text: this.newFolderName, placeholder: '分类名称' })
          .width('100%')
          .height(46)
          .fontSize(AppSizes.FONT_MD)
          .backgroundColor(AppColors.BG_SECONDARY)
          .borderRadius(AppSizes.RADIUS_SM)
          .border({ width: 1, color: AppColors.BORDER })
          .onChange((v: string) => { this.newFolderName = v })

        Row({ space: 12 }) {
          Text('取消')
            .fontSize(AppSizes.FONT_MD)
            .fontColor(AppColors.TEXT_SECONDARY)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(AppSizes.RADIUS_SM)
            .border({ width: 1, color: AppColors.BORDER })
            .onClick(() => { this.showNewFolderDialog = false })

          Text('创建')
            .fontSize(AppSizes.FONT_MD)
            .fontColor(AppColors.TEXT_WHITE)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .backgroundColor(AppColors.ACCENT)
            .borderRadius(AppSizes.RADIUS_SM)
            .onClick(() => this.confirmNewFolder())
        }
        .margin({ top: 8 })
      }
      .width('80%')
      .padding(24)
      .backgroundColor(AppColors.BG_PRIMARY)
      .borderRadius(AppSizes.RADIUS_LG)
      .shadow(AppShadows.SHADOW_LG)
    }
    .width('100%')
    .height('100%')
    .zIndex(1000)
  }

  /** 顶部导航栏 - Creamy UI */
  @Builder HeaderSection() {
    Row() {
      // 统计入口
      Column() {
        Image($r('app.media.icon_stats'))
          .width(22)
          .height(22)
          .fillColor(AppColors.TEXT_PRIMARY)
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppColors.BG_SECONDARY)
      .borderRadius(22)
      .shadow(AppShadows.SHADOW_XS)
      .onClick(() => router.pushUrl({ url: 'diary/view/pages/StatsPage' }))

      Blank()

      // 标题
      Text('学迹')
        .fontSize(AppSizes.FONT_XL)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)

      Blank()

      // 我的：底部抽屉（账号/退出）
      Row({ space: 8 }) {
        Text(this.currentUserNickname || '学迹用户')
          .fontSize(AppSizes.FONT_SM)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width(76)
          .textAlign(TextAlign.End)

        Stack() {
          if (this.currentAvatarUri.startsWith('file://')) {
            Image(this.currentAvatarUri)
              .width(36)
              .height(36)
              .borderRadius(18)
              .objectFit(ImageFit.Cover)
              .alt($r('app.media.user_dark'))
          } else {
            Image(this.currentAvatarResource())
              .width(36)
              .height(36)
              .borderRadius(18)
              .objectFit(ImageFit.Cover)
              .backgroundColor('#f5f0e8')
          }
        }
        .width(36)
        .height(36)
        .shadow(AppShadows.SHADOW_XS)
      }
      .height(44)
      .alignItems(VerticalAlign.Center)
      .margin({ left: 8 })
      .onClick(() => {
        AppStorage.setOrCreate('profile_sheet_visible', true)
      })
    }
    .width('100%')
    .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG, top: AppSizes.SPACE_MD, bottom: AppSizes.SPACE_MD })
  }

  /** 复盘入口卡片 */
  @Builder TodaySnapshotCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 3 }) {
          Text('今日学习快照')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text(this.todaySummary.recordCount > 0 ? `${this.todaySummary.recordCount} 条学习记录` : '今天还没有学习记录')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.TEXT_PRIMARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.todayHasReflection ? '已复盘' : '待复盘')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.todayHasReflection ? '#2f7d5f' : '#cc785c')
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor(this.todayHasReflection ? '#e5f3ec' : '#f8ede7')
          .borderRadius(14)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.todaySummary.recordCount > 0
        ? (this.todaySummary.titleLine || '记录已保存，今晚可以直接复盘')
        : '长按录音或点右下角文字，先留下今天的学习过程')
        .fontSize(13)
        .fontColor(AppColors.TEXT_TERTIARY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        this.SnapshotPill(this.todaySummary.categoryLine || '暂无分类')
        this.SnapshotPill(this.todaySummary.mediaLine || '无多媒体')
      }
      .width('100%')
    }
    .width('90%')
    .padding(14)
    .backgroundColor('#faf9f5')
    .borderRadius(16)
    .border({ width: 1, color: '#e6dfd8' })
    .margin({ left: '5%', right: '5%', bottom: AppSizes.SPACE_MD })
  }

  @Builder SnapshotPill(label: string) {
    Text(label)
      .fontSize(11)
      .fontColor(AppColors.TEXT_SECONDARY)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(AppColors.BG_SECONDARY)
      .borderRadius(12)
      .layoutWeight(1)
  }

  /** 复盘入口卡片 */
  @Builder ReflectionEntryCard() {
    Row({ space: 12 }) {
      // 月亮图标 - 深色夜空背景，emoji 作图标
      Column() {
        Text('🌙')
          .fontSize(22)
      }
      .width(48)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(14)
      .backgroundColor('#2a2347')

      Column({ space: 3 }) {
        Text(this.todayHasReflection ? '今日已复盘 ✓' : '今晚的反思')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#faf9f5')
        Text(this.todayHasReflection ? '点开查看今日卡片' : 'AI 引导你回顾今天学了什么')
          .fontSize(12)
          .fontColor('#bcb4e0')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(this.todayHasReflection ? '查看' : '开始')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2a2347')
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#e8a55a')
        .borderRadius(16)
    }
    .width('90%')
    .padding(14)
    .backgroundColor('#3a3160')
    .borderRadius(18)
    .border({ width: 1, color: '#4a4080' })
    .shadow({ radius: 16, color: 'rgba(42, 35, 71, 0.32)', offsetY: 4 })
    .margin({ left: '5%', right: '5%', bottom: AppSizes.SPACE_MD })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (this.todayHasReflection) {
        // 查看今日卡片：跳到该笔记
        const today = new Date()
        const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`
        const note = this.noteList.find((n: NoteItem) => n.noteType === 'reflection' && n.reflectionDate === todayStr)
        if (note) {
          router.pushUrl({ url: 'diary/view/pages/DetailPage', params: { noteId: note.id } })
        }
      } else {
        router.pushUrl({ url: 'diary/view/pages/ReflectionPage' })
      }
    })
  }

  /** 搜索栏 - Creamy Pill */
  @Builder SearchSection() {
    Row() {
      // 搜索图标
      Column() {
        IconImage({ src: $r('app.media.icon_search'), iconSize: 18, color: AppColors.TEXT_TERTIARY })
      }
      .margin({ left: AppSizes.SPACE_MD, right: AppSizes.SPACE_XS })

      TextInput({ text: this.searchText, placeholder: '搜索学习记录...' })
        .layoutWeight(1)
        .height(44)
        .backgroundColor(Color.Transparent)
        .placeholderColor(AppColors.TEXT_HINT)
        .fontSize(AppSizes.FONT_MD)
        .padding({ right: AppSizes.SPACE_MD })
        .onChange((value: string) => {
          this.searchText = value
        })
    }
    .width('90%')
    .height(50)
    .backgroundColor(AppColors.BG_SECONDARY) // 半透明白
    .borderRadius(25) // Pill shape
    .shadow(AppShadows.SHADOW_SM)
    .margin({ bottom: AppSizes.SPACE_LG })
    .alignSelf(ItemAlign.Center)
  }

  /** Tabs 切换 - 横向滚动：内置筛选 + 分类 + 新建 */
  @Builder TabsSection() {
    Scroll() {
      Row({ space: AppSizes.SPACE_SM }) {
        // 内置筛选
        ForEach(this.tabs, (item: string, index: number) => {
          Text(item)
            .fontSize(AppSizes.FONT_SM)
            .fontWeight(this.selectedTab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedTab === index ? AppColors.TEXT_WHITE : AppColors.TEXT_SECONDARY)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.selectedTab === index ? AppColors.ACCENT : AppColors.BG_SECONDARY)
            .borderRadius(20)
            .shadow(this.selectedTab === index ? AppShadows.SHADOW_SM : ShadowStyle.OUTER_DEFAULT_XS)
            .animation(AppAnimations.SPRING_FAST)
            .onClick(() => {
              this.selectedTab = index
            })
        })

        // 分隔线
        Column()
          .width(1)
          .height(20)
          .backgroundColor(AppColors.DIVIDER)
          .margin({ left: 4, right: 4 })

        // 用户分类
        ForEach(this.categories, (cat: string, idx: number) => {
          Text(cat)
            .fontSize(AppSizes.FONT_SM)
            .fontWeight(this.selectedTab === this.tabs.length + idx ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedTab === this.tabs.length + idx ? AppColors.TEXT_WHITE : AppColors.TEXT_SECONDARY)
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor(this.selectedTab === this.tabs.length + idx ? AppColors.ACCENT : AppColors.BG_SECONDARY)
            .borderRadius(20)
            .shadow(this.selectedTab === this.tabs.length + idx ? AppShadows.SHADOW_SM : ShadowStyle.OUTER_DEFAULT_XS)
            .animation(AppAnimations.SPRING_FAST)
            .onClick(() => {
              this.selectedTab = this.tabs.length + idx
            })
        }, (cat: string) => `cat_${cat}`)

        // 新建分类按钮
        Text('+')
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.ACCENT)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(AppColors.BG_SECONDARY)
          .borderRadius(20)
          .border({ width: 1, color: AppColors.ACCENT, style: BorderStyle.Dashed })
          .onClick(() => {
            this.newFolderName = ''
            this.showNewFolderDialog = true
          })
      }
      .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    .padding({ bottom: AppSizes.SPACE_MD })
  }

  /** 多选工具栏 - Premium Design */
  @Builder MultiSelectToolbar() {
    if (this.isMultiSelectMode) {
      Row({ space: 16 }) {
        Text(`已选择 ${this.selectedNoteIds.length} 项`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)

        Blank()

        // 全选按钮
        Text(this.isAllSelected() ? '取消全选' : '全选')
          .fontSize(13)
          .fontColor(AppColors.TEXT_LINK)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(AppColors.INFO_BG)
          .borderRadius(14)
          .onClick(() => this.toggleSelectAll())

        // 删除按钮
        Text('删除')
          .fontSize(13)
          .fontColor(this.selectedNoteIds.length > 0 ? AppColors.ERROR : AppColors.TEXT_HINT)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(this.selectedNoteIds.length > 0 ? AppColors.ERROR_BG : AppColors.BG_SECONDARY)
          .borderRadius(14)
          .onClick(() => this.confirmDeleteSelected())

        // 完成按钮
        Text('完成')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_WHITE)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor(AppColors.ACCENT)
          .borderRadius(14)
          .onClick(() => this.exitMultiSelect())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 12 })
    }
  }

  @Builder NoteListSection() {
    if (this.isLoading) {
      Column() {
        LoadingProgress().width(32).height(32).color(AppColors.TEXT_HINT)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.getFilteredNotes().length === 0) {
      Column({ space: 12 }) {
        Text('还没有学习记录')
          .fontSize(AppSizes.FONT_LG)
          .fontColor(AppColors.TEXT_SECONDARY)
        Text('长按下方按钮开始录音')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_HINT)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.getFilteredNotes(), (note: NoteItem) => {
          this.NoteListItem(note)
        }, (note: NoteItem) => note.id)

        ListItem() {
          Column().height(120)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder NoteListItem(note: NoteItem) {
    if (this.isMultiSelectMode) {
      ListItem() {
        this.NoteCard(note)
      }
    } else {
      ListItem() {
        this.NoteCard(note)
      }
      .swipeAction({ end: this.SwipeDeleteButton(note) })
    }
  }

  // 左滑删除按钮 - Creamy Style
  @Builder SwipeDeleteButton(note: NoteItem) {
    Row() {
      Column() {
        IconImage({ src: $r('app.media.icon_trash'), iconSize: 22, color: AppColors.TEXT_WHITE })
        Text('删除')
          .fontSize(12)
          .fontColor(AppColors.TEXT_WHITE)
          .fontWeight(FontWeight.Medium)
      }
      .width(80)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppColors.ERROR)
      .borderRadius(AppSizes.RADIUS_LG)
      .shadow(AppShadows.SHADOW_SM)
      .onClick(() => {
        AlertDialog.show({
          title: '删除记录',
          message: '确定要删除这条记录吗？',
          autoCancel: true,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: '取消',
            fontColor: AppColors.TEXT_PRIMARY,
            action: () => {}
          },
          secondaryButton: {
            value: '删除',
            fontColor: AppColors.ERROR,
            action: () => {
              this.deleteNoteWithLockCheck(note)
            }
          }
        })
      })
    }
    .height('100%')
    .padding({ left: 8 }) // Add some spacing
  }

  async deleteNote(note: NoteItem): Promise<void> {
    const context = getContext() as common.Context
    const notes = await PreferencesUtil.loadNotes(context)
    const index = notes.findIndex((n: NoteItem) => n.id === note.id)
    if (index >= 0) {
      // 记录删除时间并移动到回收站
      const deletedNote = notes[index]
      deletedNote.deletedTime = Date.now()
      
      // 保存到回收站
      const preference = await preferences.getPreferences(context, 'myNotesData')
      const deletedNotesJson = await preference.get('deletedNotes', '[]') as string
      const deletedNotesList: NoteItem[] = JSON.parse(deletedNotesJson)
      deletedNotesList.push(deletedNote)
      await preference.put('deletedNotes', JSON.stringify(deletedNotesList))
      await preference.flush()
      
      // 从主列表移除
      notes.splice(index, 1)
      await PreferencesUtil.saveNotes(context, notes)
      this.noteList = notes
      
      // 【云端同步】异步删除云端日记
      this.syncDeleteToCloud(note.id)
      
      promptAction.showToast({ message: '已移入回收站', duration: 1500 })
    }
  }

  private deleteNoteWithLockCheck(note: NoteItem): void {
    if (note.isLocked && !this.unlockedNoteIds.has(note.id)) {
      this.currentUnlockingNoteId = note.id
      this.pendingUnlockAction = 'delete'
      this.unlockPasswordInput = ''
      this.unlockError = ''
      this.showUnlockDialog = true
      return
    }
    this.deleteNote(note)
  }

  /** 异步同步删除到云端 */
  private async syncDeleteToCloud(noteId: string): Promise<void> {
    try {
      const cloudService = CloudDiaryService.getInstance()
      const initialized = await cloudService.initialize()
      if (initialized) {
        await cloudService.deleteNote(noteId)
        console.info('[HomePage] 云端日记删除成功:', noteId)
      }
    } catch (err) {
      console.warn('[HomePage] 云端日记删除失败:', err)
      // 失败静默，不影响本地操作
    }
  }

  /** 进入多选模式并选中指定日记 */
  enterMultiSelect(initialId?: string): void {
    if (!this.isMultiSelectMode) {
      this.isMultiSelectMode = true
    }
    if (initialId && !this.selectedNoteIds.includes(initialId)) {
      this.selectedNoteIds = [...this.selectedNoteIds, initialId]
    }
  }

  /** 切换日记选中状态 */
  toggleNoteSelection(noteId: string): void {
    if (!this.isMultiSelectMode) {
      this.enterMultiSelect(noteId)
      return
    }

    if (this.selectedNoteIds.includes(noteId)) {
      this.selectedNoteIds = this.selectedNoteIds.filter((id: string) => id !== noteId)
    } else {
      this.selectedNoteIds = [...this.selectedNoteIds, noteId]
    }
  }

  /** 取消多选状态 */
  exitMultiSelect(): void {
    this.isMultiSelectMode = false
    this.selectedNoteIds = []
  }

  /** 判断是否已选中 */
  isNoteSelected(noteId: string): boolean {
    return this.selectedNoteIds.includes(noteId)
  }

  /** 检查是否已全选 */
  isAllSelected(): boolean {
    const visibleIds = this.getFilteredNotes().map((n: NoteItem) => n.id)
    if (visibleIds.length === 0) return false
    return visibleIds.every((id: string) => this.selectedNoteIds.includes(id))
  }

  /** 全选或取消全选 */
  toggleSelectAll(): void {
    if (this.isAllSelected()) {
      this.selectedNoteIds = []
      return
    }
    const visibleIds = this.getFilteredNotes().map((n: NoteItem) => n.id)
    this.selectedNoteIds = [...visibleIds]
  }

  /** 删除多选日记（弹窗确认） */
  confirmDeleteSelected(): void {
    if (this.selectedNoteIds.length === 0) {
      promptAction.showToast({ message: '请先选择记录', duration: 1500 })
      return
    }

    const lockedCount = this.noteList.filter((note: NoteItem) =>
      this.selectedNoteIds.includes(note.id) && note.isLocked && !this.unlockedNoteIds.has(note.id)
    ).length
    if (lockedCount > 0) {
      promptAction.showToast({ message: '加锁记录需先输入密码后再删除', duration: 1800 })
      return
    }

    AlertDialog.show({
      title: '删除记录',
      message: `确定要删除选中的${this.selectedNoteIds.length}条记录吗？`,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: AppColors.ERROR,
        action: () => {
          this.deleteSelectedNotes()
        }
      }
    })
  }

  /** 执行删除已选日记 */
  async deleteSelectedNotes(): Promise<void> {
    if (this.selectedNoteIds.length === 0) return
    const context = getContext() as common.Context
    const notes = await PreferencesUtil.loadNotes(context)
    const remaining = notes.filter((n: NoteItem) => !this.selectedNoteIds.includes(n.id))
    await PreferencesUtil.saveNotes(context, remaining)
    this.noteList = remaining
    promptAction.showToast({ message: `已删除${notes.length - remaining.length}条记录`, duration: 1500 })
    this.exitMultiSelect()
  }

  /** 日记卡片 - Creamy UI */
  @Builder NoteCard(note: NoteItem) {
    LearningRecordCard({
      note: note,
      isSelected: this.isNoteSelected(note.id),
      isPressed: this.pressedCardId === note.id,
      isMultiSelectMode: this.isMultiSelectMode,
      onOpen: (noteId: string) => this.openNote(noteId),
      onToggleSelect: (noteId: string) => this.toggleNoteSelection(noteId),
      onLongPress: (noteId: string) => this.enterMultiSelect(noteId),
      onPressChange: (noteId: string, pressed: boolean) => {
        this.pressedCardId = pressed ? noteId : ''
      }
    })
  }

  openNote(noteId: string): void {
    const note = this.noteList.find((item: NoteItem) => item.id === noteId)
    if (!note) {
      return
    }
    if (note.isLocked && !this.unlockedNoteIds.has(note.id)) {
      this.currentUnlockingNoteId = note.id
      this.pendingUnlockAction = 'open'
      this.unlockPasswordInput = ''
      this.unlockError = ''
      this.showUnlockDialog = true
    } else {
      router.pushUrl({ url: 'diary/view/pages/DetailPage', params: { noteId: note.id } })
    }
  }

  // 验证密码并打开日记
  confirmUnlock(): void {
    const note = this.noteList.find((n: NoteItem) => n.id === this.currentUnlockingNoteId)
    if (note && this.unlockPasswordInput === note.password) {
      // 任务3.7：缓存已解锁的日记ID
      this.unlockedNoteIds.add(note.id)
      this.showUnlockDialog = false
      if (this.pendingUnlockAction === 'delete') {
        this.pendingUnlockAction = 'open'
        this.deleteNote(note)
        return
      }
      // 问题11修复：传递preUnlocked避免二次验证
      router.pushUrl({
        url: 'diary/view/pages/DetailPage',
        params: { noteId: note.id, preUnlocked: true }
      })
    } else {
      this.unlockError = '密码错误'
    }
  }

  // 创建新文件夹
  confirmNewFolder(): void {
    const name = this.newFolderName.trim()
    if (!name) {
      promptAction.showToast({ message: '请输入分类名称', duration: 1500 })
      return
    }
    if (this.categories.includes(name)) {
      promptAction.showToast({ message: '分类已存在', duration: 1500 })
      return
    }
    this.categories = [...this.categories, name]
    this.showNewFolderDialog = false
    this.newFolderName = ''
    promptAction.showToast({ message: '分类已创建', duration: 1500 })
  }

  // 录音浮层 - Creamy Glass Design
  @Builder RecordingOverlay() {
    Stack() {
      // 模糊背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(255, 255, 255, 0.8)')
        .backdropBlur(40)

      // 主内容
      Column({ space: 0 }) {
        // 顶部区域
        Row() {
          Blank()
          // 取消按钮
          Text('取消')
            .fontSize(16)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 24, right: 24, top: 12, bottom: 12 })
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(24)
            .shadow(AppShadows.SHADOW_SM)
            .onClick(() => {
              this.cancelRecording()
            })
        }
        .width('100%')
        .padding({ top: this.topSafeHeight + 16, left: 24, right: 24 })

        Blank().layoutWeight(1)

        // 中央录音指示区域
        Column({ space: 24 }) {
          // Canvas 声波动画
          Stack() {
            // 声波动画 Canvas
            VoiceWaveCanvas({
              volume: this.currentVolume,
              isRecording: this.isRecording,
              canvasWidth: 240,
              canvasHeight: 240,
              primaryColor: AppColors.ACCENT
            })

            // 中心时间显示
            Column() {
              Text(this.formatRecordingTime(this.recordingSeconds))
                .fontSize(28)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_PRIMARY)
            }
            .width(80)
            .height(80)
            .borderRadius(50)
            .backgroundColor(AppColors.BG_SECONDARY)
            .shadow(AppShadows.SHADOW_MD)
            .justifyContent(FlexAlign.Center)
          }
          .width(200)
          .height(200)

          // 状态文字
          Row({ space: 8 }) {
            Circle()
              .width(8)
              .height(8)
              .fill('#FF3B30')
            Text(this.isRecording ? '录音中' : '准备中')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
            
            // 音量条
            if (this.isRecording) {
              Row({ space: 2 }) {
                VoiceWaveBars({
                  volume: this.currentVolume,
                  isRecording: this.isRecording,
                  barCount: 5,
                  primaryColor: AppColors.ACCENT
                })
              }
              .height(16)
              .width(40)
              .margin({ left: 8 })
            }
          }
        }

        Blank().height(40)

        // 实时识别文字区域 - 卡片设计
        Column({ space: 16 }) {
          // 标题行
          Row() {
            Row({ space: 6 }) {
              // 波形图标
              Row({ space: 2 }) {
                ForEach([3, 5, 7, 5, 3], (h: number, i: number) => {
                  Column()
                    .width(2)
                    .height(this.isRecognizing ? h + Math.sin(Date.now() / 200 + i) * 3 : h)
                    .borderRadius(1)
                    .backgroundColor(AppColors.SUCCESS)
                }, (h: number, i: number) => `wave_${i}`)
              }
              Text('语音识别')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.TEXT_TERTIARY)
            }

            Blank()

            if (this.isRecognizing) {
              Row({ space: 4 }) {
                LoadingProgress()
                  .width(12)
                  .height(12)
                  .color(AppColors.SUCCESS)
                Text('识别中')
                  .fontSize(11)
                  .fontColor(AppColors.SUCCESS)
              }
            }
          }
          .width('100%')

          // 识别文字
          Scroll() {
            Text(this.recognizedText || '正在聆听您的声音...')
              .fontSize(AppSizes.FONT_MD)
              .fontColor(this.recognizedText ? AppColors.TEXT_PRIMARY : AppColors.TEXT_TERTIARY)
              .lineHeight(26)
              .width('100%')
              .animation(AppAnimations.SPRING_NORMAL)
          }
          .width('100%')
          .constraintSize({ maxHeight: 120 })
        }
        .width('100%')
        .padding(AppSizes.SPACE_LG)
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius(AppSizes.RADIUS_LG)
        .shadow(AppShadows.SHADOW_SM)
        .margin({ left: 24, right: 24 })

        Blank().layoutWeight(1)

        // 底部提示 - 根据上滑状态变化
        Column({ space: 8 }) {
          if (this.isInCancelZone) {
            // 已进入取消区域
            Column({ space: 8 }) {
              IconImage({ src: $r('app.media.icon_trash'), iconSize: 28, color: AppColors.ERROR })
              Text('松开取消录音')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppColors.ERROR)
            }
            .padding(16)
            .backgroundColor(AppColors.BG_SECONDARY)
            .borderRadius(12)
            .shadow(AppShadows.SHADOW_SM)
          } else {
            // 正常状态
            Text('↑ 上滑取消')
              .fontSize(13)
              .fontColor(AppColors.TEXT_TERTIARY)
            Text('松开按钮停止录音')
              .fontSize(14)
              .fontColor(AppColors.TEXT_SECONDARY)
            
            // 上滑进度指示
            if (this.dragOffsetY > 20) {
              Row({ space: 4 }) {
                Text('继续上滑')
                  .fontSize(12)
                  .fontColor(AppColors.TEXT_TERTIARY)
                Text(`${Math.min(100, Math.round(this.dragOffsetY / this.CANCEL_THRESHOLD * 100))}%`)
                  .fontSize(12)
                  .fontColor(AppColors.ERROR)
              }
              .margin({ top: 8 })
            }
          }
        }
        .margin({ bottom: this.bottomSafeHeight + 100 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
    .zIndex(9999)
  }

  // 格式化录音时长
  formatRecordingTime(seconds: number): string {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
  }
  
  // 取消录音
  async cancelRecording(): Promise<void> {
    this.isRecording = false
    this.showRecordingOverlay = false
    this.stopRecordingAnimation()
    clearInterval(this.recordingTimer)
    
    try {
      if (this.asrEngine && this.asrSessionId) {
        this.asrEngine.cancel(this.asrSessionId)
        this.asrEngine.shutdown()
        this.asrEngine = null
        this.asrSessionId = ''
      }
      await this.audioRecorder.stopRecording()
    } catch (e) {
      console.warn('[HomePage] 取消录音失败:', e)
    }
    
    this.recognizedText = ''
    this.accumulatedText = ''
    this.isRecognizing = false
    this.recordButtonScale = 1
    promptAction.showToast({ message: '已取消', duration: 1000 })
  }

  /** 录音按钮 - 2025 Premium Design */
  @Builder RecordingButton() {
    Column({ space: 8 }) {
      Stack() {
        // 外圈脉冲动画
        if (this.isRecording) {
          Circle()
            .width(72)
            .height(72)
            .fill(Color.Transparent)
            .stroke(AppColors.RECORDING)
            .strokeWidth(2)
            .scale({ x: this.waveScale, y: this.waveScale })
            .opacity(2 - this.waveScale)

          Circle()
            .width(84)
            .height(84)
            .fill(Color.Transparent)
            .stroke(AppColors.RECORDING)
            .strokeWidth(1)
            .scale({ x: this.waveScale * 1.1, y: this.waveScale * 1.1 })
            .opacity((2 - this.waveScale) * 0.5)
        }

        // 主按钮 - Swiss Spa 极简设计
        Column() {
          if (this.isProcessing) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color(AppColors.TEXT_WHITE)
          } else if (this.isRecording) {
            // 停止图标 - 圆角方块
            Column()
              .width(14)
              .height(14)
              .borderRadius(2)
              .backgroundColor(AppColors.TEXT_WHITE)
          } else {
            // 麦克风图标 - 极简现代设计 🎙️
            Stack() {
              // 麦克风头部 - 圆润胶囊形
              Column()
                .width(10)
                .height(14)
                .borderRadius(5)
                .backgroundColor(AppColors.TEXT_WHITE)
                .position({ x: 9, y: 0 })

              // 麦克风支架 - 优雅U形弧线
              Column()
                .width(18)
                .height(9)
                .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 9, bottomRight: 9 })
                .backgroundColor(Color.Transparent)
                .border({ width: { left: 2, right: 2, bottom: 2 }, color: AppColors.TEXT_WHITE })
                .position({ x: 5, y: 8 })

              // 支架竖杆
              Column()
                .width(2)
                .height(5)
                .backgroundColor(AppColors.TEXT_WHITE)
                .position({ x: 13, y: 17 })

              // 底座横杆
              Column()
                .width(10)
                .height(2)
                .borderRadius(1)
                .backgroundColor(AppColors.TEXT_WHITE)
                .position({ x: 9, y: 22 })
            }
            .width(28)
            .height(26)
          }
        }
        .width(52)
        .height(52)
        .borderRadius(26)
        .backgroundColor(this.isRecording ? AppColors.TEXT_PRIMARY : AppColors.BG_DARK_SECONDARY)  // 深灰色系
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .scale({ x: this.recordButtonScale, y: this.recordButtonScale })
        .shadow(AppShadows.SHADOW_MD)
      }

      Text(this.isProcessing ? '处理中...' : (this.isRecording ? (this.isInCancelZone ? '松开取消' : '松开停止') : '长按录音'))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isInCancelZone ? AppColors.ERROR : AppColors.TEXT_SECONDARY)
    }
    // 录音按钮定位在中间
    .position({ x: '50%', y: '100%' })
    .translate({ x: '-50%', y: -this.bottomSafeHeight - 110 })
    .onTouch((e: TouchEvent) => {
      const touch = e.touches[0];
      
      if (e.type === TouchType.Down && !this.isRecording && !this.isProcessing) {
        // 记录起始位置
        this.touchStartY = touch.y;
        this.dragOffsetY = 0;
        this.isInCancelZone = false;
        animateTo({ duration: 100 }, () => { this.recordButtonScale = 0.92 })
        this.startRecording()
      } else if (e.type === TouchType.Move && this.isRecording) {
        // 计算上滑距离
        this.dragOffsetY = this.touchStartY - touch.y;
        // 判断是否进入取消区域
        const wasInCancelZone = this.isInCancelZone;
        this.isInCancelZone = this.dragOffsetY > this.CANCEL_THRESHOLD;
        // 进入/离开取消区域时的反馈
        if (this.isInCancelZone !== wasInCancelZone) {
          // 可以添加振动反馈
          this.recordButtonScale = this.isInCancelZone ? 0.85 : 0.92;
        }
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({ duration: 200 }, () => { this.recordButtonScale = 1 })
        
        if (this.isInCancelZone) {
          // 上滑取消
          this.cancelRecording();
        } else {
          // 正常停止录音
          this.stopRecording();
        }
        
        // 重置状态
        this.touchStartY = 0;
        this.dragOffsetY = 0;
        this.isInCancelZone = false;
      }
    })

    // 文字记录按钮 - 右侧
    Column({ space: 4 }) {
      Column() {
        Text('✏️')
          .fontSize(20)
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .backgroundColor(AppColors.BG_SECONDARY)
      .justifyContent(FlexAlign.Center)
      .shadow(AppShadows.SHADOW_SM)
      .onClick(() => {
        // 直接跳转到 DetailPage 新建模式
        router.pushUrl({ url: 'diary/view/pages/DetailPage' })
      })

      Text('文字')
        .fontSize(11)
        .fontColor(AppColors.TEXT_TERTIARY)
    }
    .position({ x: '75%', y: '100%' })
    .translate({ x: '-50%', y: -this.bottomSafeHeight - 100 })
  }

}
