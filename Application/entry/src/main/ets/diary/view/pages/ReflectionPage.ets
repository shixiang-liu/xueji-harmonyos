// 每晚 5 分钟复盘对话页 - AI 引导式提问，对话结束后生成今日复盘卡片
import { router, promptAction } from '@kit.ArkUI'
import window from '@ohos.window'
import { common } from '@kit.AbilityKit'
import { LongCatService, ReflectionSummaryResult } from '../../../common/services/LongCatService'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { NoteItem } from '../../model/NoteItem'
import { AppColors, AppSizes, AppShadows } from '../../../common/utils/AppTheme'
import { IconImage } from '../../../common/components/IconImage'
import { REFLECTION_CATEGORY } from '../../utils/LearningCategories'
import { buildLearningDaySummary, LearningDaySummary } from '../../utils/LearningDaySummary'
import { GlobalAskAIFab } from '../../../common/components/GlobalAskAIFab'

interface ChatMessage {
  role: string  // 'user' | 'assistant'
  content: string
}

const MAX_TURNS: number = 10  // 安全上限，正常由用户主动结束

@Entry
@Component
struct ReflectionPage {
  @State messages: ChatMessage[] = []
  @State userInput: string = ''
  @State isAILoading: boolean = false
  @State isFinishing: boolean = false
  @State turnIndex: number = 0  // AI 已经发了几轮
  @State topSafeHeight: number = 0
  @State bottomSafeHeight: number = 0
  @State lastUnresolved: string[] = []
  @State summaryResult: ReflectionSummaryResult | null = null
  @State showFinishConfirm: boolean = false
  @State savedNoteId: string = ''
  @State todaySummary: LearningDaySummary = new LearningDaySummary()
  private scroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    await this.setFullScreen()
    await this.loadYesterdayUnresolved()
    await this.loadTodaySummary()
    await this.startReflection()
  }

  private turnProgressText(): string {
    if (this.summaryResult) {
      return '已生成今日卡片'
    }
    if (this.turnIndex <= 0) {
      return 'AI 引导复盘'
    }
    return '聊完点「结束复盘」即可生成卡片'
  }

  private async setFullScreen(): Promise<void> {
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

  private async loadTodaySummary(): Promise<void> {
    try {
      const context = getContext(this) as common.Context
      const allNotes = await PreferencesUtil.loadNotes(context)
      this.todaySummary = buildLearningDaySummary(allNotes, Date.now())
    } catch (e) {
      console.warn('[ReflectionPage] 加载今日学习摘要失败:', e)
      this.todaySummary = new LearningDaySummary()
    }
  }

  /** 加载昨天的复盘卡片，提取未解决的困惑供 AI 主动追问 */
  private async loadYesterdayUnresolved(): Promise<void> {
    try {
      const context = getContext(this) as common.Context
      const allNotes = await PreferencesUtil.loadNotes(context)
      const reflections = allNotes.filter((n: NoteItem) => n.noteType === 'reflection')
      reflections.sort((a, b) => (b.createTime || 0) - (a.createTime || 0))
      // 找最近一条且未解决的
      for (const r of reflections) {
        if (r.unresolvedQuestions && r.unresolvedQuestions.length > 0 && !r.questionsResolved) {
          this.lastUnresolved = r.unresolvedQuestions.slice(0, 3)
          break
        }
      }
    } catch (e) {
      console.warn('[ReflectionPage] 加载昨日困惑失败:', e)
    }
  }

  /** 开场：AI 主动说第一句 */
  private async startReflection(): Promise<void> {
    this.isAILoading = true
    const opening = await LongCatService.getInstance().reflectionTurn([], this.lastUnresolved, 0, this.todaySummary.promptContext)
    this.messages.push({ role: 'assistant', content: opening })
    this.turnIndex = 1
    this.isAILoading = false
    this.scrollToBottom()
  }

  /** 用户发送一条消息 */
  private async sendUserMessage(): Promise<void> {
    const text = this.userInput.trim()
    if (text.length === 0 || this.isAILoading || this.isFinishing) return
    this.messages.push({ role: 'user', content: text })
    this.userInput = ''
    this.scrollToBottom()

    // 安全上限：达到最大轮数自动收尾
    if (this.turnIndex >= MAX_TURNS) {
      await this.finishReflection()
      return
    }

    this.isAILoading = true
    const history: ChatMessage[] = this.messages.slice()
    const aiResponse = await LongCatService.getInstance().reflectionTurn(history, this.lastUnresolved, this.turnIndex, this.todaySummary.promptContext)
    this.messages.push({ role: 'assistant', content: aiResponse })
    this.turnIndex += 1
    this.isAILoading = false
    this.scrollToBottom()
  }

  /** 完成复盘：调 AI 生成卡片 + 保存为 NoteItem */
  private async finishReflection(): Promise<void> {
    if (this.isFinishing || this.summaryResult) return
    this.isFinishing = true
    this.scrollToBottom()
    try {
      const summary = await LongCatService.getInstance().reflectionSummary(this.messages.slice(), this.todaySummary.promptContext)
      this.summaryResult = summary
      await this.saveReflectionNote(summary)
      // 标记昨天的困惑已解决（如果用户在对话中提到了）
      await this.markYesterdayResolved()
    } catch (e) {
      console.error('[ReflectionPage] finish error:', e)
      promptAction.showToast({ message: '生成卡片失败：' + (e as Error).message, duration: 2000 })
    }
    this.isFinishing = false
  }

  private async saveReflectionNote(summary: ReflectionSummaryResult): Promise<void> {
    const note = new NoteItem()
    note.id = `reflection_${Date.now()}`
    this.savedNoteId = note.id
    note.noteType = 'reflection'
    note.category = REFLECTION_CATEGORY
    note.title = summary.title || '今日复盘'
    note.content = this.formatReflectionContent(summary)
    note.createTime = Date.now()
    note.lastModifiedTime = Date.now()
    note.date = this.formatDate(Date.now())
    note.reflectionDate = this.formatDateOnly(Date.now())
    note.reflectionMessages = JSON.stringify(this.messages)
    note.reflectionTakeaways = summary.takeaways
    note.unresolvedQuestions = summary.questions
    note.reflectionPlan = summary.plan
    note.questionsResolved = false

    const context = getContext(this) as common.Context
    await PreferencesUtil.saveNote(context, note)
    AppStorage.setOrCreate('diaryUpdatedAt', Date.now())
  }

  private formatReflectionContent(summary: ReflectionSummaryResult): string {
    const parts: string[] = []
    if (summary.takeaways.length > 0) {
      parts.push('【学到】\n' + summary.takeaways.map(t => '· ' + t).join('\n'))
    }
    if (summary.questions.length > 0) {
      parts.push('【困惑】\n' + summary.questions.map(q => '· ' + q).join('\n'))
    }
    if (summary.plan.length > 0) {
      parts.push('【明日】\n' + summary.plan.map(p => '· ' + p).join('\n'))
    }
    return parts.join('\n\n')
  }

  private async markYesterdayResolved(): Promise<void> {
    if (this.lastUnresolved.length === 0) return
    try {
      const context = getContext(this) as common.Context
      const allNotes = await PreferencesUtil.loadNotes(context)
      const reflections = allNotes.filter((n: NoteItem) => n.noteType === 'reflection' && !n.questionsResolved)
      reflections.sort((a, b) => (b.createTime || 0) - (a.createTime || 0))
      // 跳过今天刚保存的，找昨天那条
      for (const r of reflections) {
        if (r.unresolvedQuestions && r.unresolvedQuestions.length > 0 &&
            r.unresolvedQuestions.join('|') === this.lastUnresolved.join('|')) {
          r.questionsResolved = true
          await PreferencesUtil.saveNote(context, r)
          break
        }
      }
    } catch (e) {
      console.warn('[ReflectionPage] markResolved 失败:', e)
    }
  }

  private formatDate(ts: number): string {
    const d = new Date(ts)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }

  private formatDateOnly(ts: number): string {
    const d = new Date(ts)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom)
    }, 100)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 顶部
        Column().width('100%').height(this.topSafeHeight).backgroundColor(AppColors.BG_PRIMARY)

        Row() {
          Column() {
            IconImage({ src: $r('app.media.icon_arrow_back'), iconSize: 20, color: AppColors.TEXT_PRIMARY })
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(20)
          .backgroundColor(AppColors.BG_SECONDARY)
          .border({ width: 1, color: AppColors.BORDER })
          .onClick(() => router.back())

          Column({ space: 2 }) {
            Row({ space: 6 }) {
              IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 16, color: '#cc785c' })
              Text('今晚复盘')
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppColors.TEXT_PRIMARY)
            }
            .alignItems(VerticalAlign.Center)
            Text(this.turnProgressText())
              .fontSize(11)
              .fontColor(AppColors.TEXT_TERTIARY)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)

          Column().width(40)
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)

        // 对话区
        Scroll(this.scroller) {
          Column({ space: 12 }) {
            this.TodayContextCard()

            ForEach(this.messages, (msg: ChatMessage, idx: number) => {
              this.MessageBubble(msg)
            }, (msg: ChatMessage, idx: number) => `${idx}_${msg.role}`)

            if (this.isAILoading) {
              this.LoadingBubble()
            }

            if (this.summaryResult) {
              this.SummaryCard()
            }

            // 底部留白避让输入框
            Column().height(80)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)

        // 底部输入区
        if (this.summaryResult) {
          this.FinishedFooter()
        } else {
          this.InputBar()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG_PRIMARY)

      Column() {
        GlobalAskAIFab({ bottomOffset: this.bottomSafeHeight + 110 })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.End)
      .hitTestBehavior(HitTestMode.Transparent)

      // 结束复盘确认弹窗
      if (this.showFinishConfirm) {
        Column() {
          Column({ space: 16 }) {
            Text('结束复盘？')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor('#141413')
            Text('将根据本次对话生成今日复盘卡片')
              .fontSize(14)
              .fontColor('#6c6a64')
            Row({ space: 12 }) {
              Text('再聊聊')
                .fontSize(15)
                .fontColor('#6c6a64')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .padding({ top: 10, bottom: 10 })
                .backgroundColor('#f5f0e8')
                .borderRadius(20)
                .onClick(() => { this.showFinishConfirm = false })
              Text('生成卡片')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#ffffff')
                .textAlign(TextAlign.Center)
                .layoutWeight(1)
                .padding({ top: 10, bottom: 10 })
                .backgroundColor('#cc785c')
                .borderRadius(20)
                .onClick(() => {
                  this.showFinishConfirm = false
                  this.finishReflection()
                })
            }
          }
          .width('80%')
          .padding(24)
          .backgroundColor('#ffffff')
          .borderRadius(20)
          .shadow({ radius: 24, color: '#1a000000', offsetY: 4 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#4d000000')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => { this.showFinishConfirm = false })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TodayContextCard() {
    Column({ space: 6 }) {
      Text(this.todaySummary.recordCount > 0 ? `今天已有 ${this.todaySummary.recordCount} 条学习记录` : '今天还没有普通学习记录')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#6c6a64')
      Text(this.todaySummary.recordCount > 0
        ? `${this.todaySummary.categoryLine || '暂无分类'}${this.todaySummary.mediaLine ? ' · ' + this.todaySummary.mediaLine : ''}`
        : '可以先聊聊今天学过但还没记录下来的内容')
        .fontSize(12)
        .fontColor('#8e8b82')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .backgroundColor('#f5f0e8')
    .borderRadius(14)
    .border({ width: 1, color: '#e6dfd8' })
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    if (msg.role === 'user') {
      Row() {
        Blank().layoutWeight(1)
        Column() {
          Text(msg.content)
            .fontSize(15)
            .fontColor('#ffffff')
            .lineHeight(22)
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#cc785c')
        .borderRadius({ topLeft: 16, topRight: 16, bottomLeft: 16, bottomRight: 4 })
        .constraintSize({ maxWidth: '78%' })
      }
      .width('100%')
    } else {
      Row({ space: 8 }) {
        Column() {
          IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 14, color: '#cc785c' })
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(14)
        .backgroundColor('#f5f0e8')

        Column() {
          Text(msg.content)
            .fontSize(15)
            .fontColor('#252523')
            .lineHeight(22)
            .copyOption(CopyOptions.LocalDevice)
        }
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#faf9f5')
        .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
        .border({ width: 1, color: '#e6dfd8' })
        .constraintSize({ maxWidth: '78%' })

        Blank().layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  LoadingBubble() {
    Row({ space: 8 }) {
      Column() {
        IconImage({ src: $r('app.media.icon_sparkle'), iconSize: 14, color: '#cc785c' })
      }
      .width(28)
      .height(28)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius(14)
      .backgroundColor('#f5f0e8')

      Row({ space: 6 }) {
        LoadingProgress().width(14).height(14).color('#cc785c')
        Text(this.isFinishing ? '正在整理今日卡片…' : '思考中…')
          .fontSize(13)
          .fontColor('#8e8b82')
      }
      .alignItems(VerticalAlign.Center)
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor('#faf9f5')
      .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
      .border({ width: 1, color: '#e6dfd8' })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  SummaryCard() {
    if (this.summaryResult) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          IconImage({ src: $r('app.media.icon_check_circle'), iconSize: 18, color: '#16A34A' })
          Text(this.summaryResult.title || '今日复盘')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#141413')
        }
        .alignItems(VerticalAlign.Center)
        .alignSelf(ItemAlign.Start)

        if (this.summaryResult.takeaways.length > 0) {
          this.SummarySection('学到', this.summaryResult.takeaways, '#16A34A')
        }
        if (this.summaryResult.questions.length > 0) {
          this.SummarySection('困惑', this.summaryResult.questions, '#cc785c')
        }
        if (this.summaryResult.plan.length > 0) {
          this.SummarySection('明日', this.summaryResult.plan, '#5db8a6')
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#ffffff')
      .borderRadius(16)
      .border({ width: 1, color: '#e6dfd8' })
      .shadow(AppShadows.SHADOW_SM)
      .margin({ top: 8 })
    }
  }

  @Builder
  SummarySection(label: string, items: string[], accent: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(accent)
        .letterSpacing(1.5)
      ForEach(items, (item: string) => {
        Row({ space: 8 }) {
          Column()
            .width(4)
            .height(4)
            .borderRadius(2)
            .backgroundColor(accent)
            .margin({ top: 8 })
          Text(item)
            .fontSize(14)
            .fontColor('#252523')
            .lineHeight(22)
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Top)
        .width('100%')
      })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  InputBar() {
    Column({ space: 8 }) {
      // 结束复盘按钮 - 只要聊了至少1轮且未在生成中就显示
      if (this.turnIndex >= 1 && !this.isFinishing && !this.summaryResult) {
        Text(this.isFinishing ? '正在生成卡片…' : '结束复盘，生成今日卡片')
          .fontSize(13)
          .fontColor(this.isFinishing ? '#a09d96' : '#cc785c')
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ top: 8, bottom: 4 })
          .onClick(() => { this.showFinishConfirm = true })
      }
      Row({ space: 10 }) {
        TextInput({ text: this.userInput, placeholder: '说说你的想法…' })
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor('#141413')
          .placeholderColor('#a09d96')
          .backgroundColor('#faf9f5')
          .borderRadius(22)
          .border({ width: 1, color: '#e6dfd8' })
          .padding({ left: 16, right: 16 })
          .enabled(!this.isAILoading && !this.isFinishing)
          .onChange((v: string) => { this.userInput = v })
          .onSubmit(() => { this.sendUserMessage() })

        Column() {
          IconImage({ src: $r('app.media.icon_arrow_back'), iconSize: 18, color: '#ffffff' })
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(22)
        .backgroundColor(this.userInput.trim().length > 0 && !this.isAILoading ? '#cc785c' : '#e6dfd8')
        .rotate({ angle: 90 })  // 用返回箭头转 90 度当发送图标
        .onClick(() => this.sendUserMessage())
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: this.bottomSafeHeight + 10 })
    .backgroundColor(AppColors.BG_PRIMARY)
    .border({ width: { top: 1 }, color: AppColors.BORDER })
  }

  @Builder
  FinishedFooter() {
    Row({ space: 10 }) {
      Text('查看今日卡片')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#cc785c')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })
        .backgroundColor('#faf9f5')
        .borderRadius(22)
        .border({ width: 1, color: '#e6dfd8' })
        .onClick(() => {
          router.pushUrl({
            url: 'diary/view/pages/DetailPage',
            params: { noteId: this.savedNoteId }
          })
        })

      Text('完成')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#ffffff')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })
        .backgroundColor('#cc785c')
        .borderRadius(22)
        .onClick(() => router.back())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: this.bottomSafeHeight + 10 })
    .backgroundColor(AppColors.BG_PRIMARY)
    .border({ width: { top: 1 }, color: AppColors.BORDER })
  }
}
