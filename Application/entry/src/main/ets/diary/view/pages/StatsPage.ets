import { router } from '@kit.ArkUI'
import common from '@ohos.app.ability.common'
import window from '@ohos.window'
import { NoteItem } from '../../model/NoteItem'
import { normalizeLearningCategory } from '../../utils/LearningCategories'
import { PreferencesUtil } from '../../../common/utils/PreferencesUtil'
import { AppColors, AppSizes, AppShadows } from '../../../common/utils/AppTheme'

interface RichEditorSpanStats {
  type?: string
  value?: string
  linkTitle?: string
}

interface TextLikeContentBlockStats {
  type: string
  text?: string
  title?: string
}

@Entry
@Component
struct StatsPage {
  @StorageProp('diaryUpdatedAt') @Watch('onDiaryUpdated') diaryUpdatedAt: number = 0
  @State noteList: NoteItem[] = []
  @State topSafeHeight: number = 0
  @State bottomSafeHeight: number = 0

  @State totalNotes: number = 0
  @State totalRecordings: number = 0
  @State totalImages: number = 0
  @State totalWords: number = 0
  @State currentStreak: number = 0
  @State longestStreak: number = 0
  @State thisWeekNotes: number = 0
  @State lastWeekNotes: number = 0
  @State thisWeekWords: number = 0
  @State weekActiveDays: number = 0

  @State topCategoryName: string = '暂无'
  @State topCategoryCount: number = 0
  @State categoryNames: string[] = []
  @State categoryValues: number[] = []
  @State categoryPercents: number[] = []

  @State insightTitles: string[] = []
  @State insightBodies: string[] = []
  @State insightColors: string[] = []

  @State contentProgress: number = 0

  private readonly DAY_MS: number = 86400000
  private readonly CATEGORY_COLORS: string[] = ['#cc785c', '#5db8a6', '#e8a55a', '#7c8cf5', '#5db872']

  async aboutToAppear(): Promise<void> {
    await this.setFullScreen()
    await this.loadAndCompute()
    setTimeout(() => {
      animateTo({ duration: 520, curve: Curve.EaseOut }, () => {
        this.contentProgress = 1
      })
    }, 120)
  }

  async onPageShow(): Promise<void> {
    await this.loadAndCompute()
  }

  onDiaryUpdated(): void {
    this.loadAndCompute()
  }

  async setFullScreen(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const win = await window.getLastWindow(ctx)
      const topArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      const bottomArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      this.topSafeHeight = px2vp(topArea.topRect.height)
      this.bottomSafeHeight = px2vp(bottomArea.bottomRect.height)
      win.setWindowLayoutFullScreen(true)
    } catch (e) {
      this.topSafeHeight = 44
      this.bottomSafeHeight = 24
      console.error('[StatsPage] setFullScreen:', e)
    }
  }

  async loadAndCompute(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext
      const notes = await PreferencesUtil.loadNotes(ctx)
      this.noteList = notes.filter((note: NoteItem) =>
        note && note.id && (note.deletedTime || 0) === 0
      )
      this.computeStats()
      this.computeStreakAndWeeks()
      this.computeCategories()
      this.buildInsights()
    } catch (e) {
      this.noteList = []
      this.computeStats()
      this.computeStreakAndWeeks()
      this.computeCategories()
      this.buildInsights()
      console.error('[StatsPage] loadAndCompute:', e)
    }
  }

  computeStats(): void {
    const notes = this.noteList
    this.totalNotes = notes.length
    this.totalRecordings = notes.reduce((sum: number, note: NoteItem) => sum + (note.recordings?.length ?? 0), 0)
    this.totalImages = notes.reduce((sum: number, note: NoteItem) => sum + (note.images?.length ?? 0), 0)
    this.totalWords = notes.reduce((sum: number, note: NoteItem) => sum + this.noteWordCount(note), 0)
  }

  computeStreakAndWeeks(): void {
    const notes = this.noteList
    const today = this.dayStart(Date.now())
    const daySet = new Set<number>()
    for (const note of notes) {
      const activityTime = this.noteActivityTime(note)
      if (activityTime) {
        daySet.add(this.dayStart(activityTime))
      }
    }

    const sorted = Array.from(daySet).sort((a: number, b: number) => a - b)
    let longest = 0
    let running = 0
    for (let i = 0; i < sorted.length; i++) {
      if (i === 0 || sorted[i] - sorted[i - 1] !== this.DAY_MS) {
        running = 1
      } else {
        running += 1
      }
      longest = Math.max(longest, running)
    }
    this.longestStreak = longest

    let streak = 0
    let checkDay = today
    while (daySet.has(checkDay)) {
      streak += 1
      checkDay -= this.DAY_MS
    }
    if (streak === 0) {
      checkDay = today - this.DAY_MS
      while (daySet.has(checkDay)) {
        streak += 1
        checkDay -= this.DAY_MS
      }
    }
    this.currentStreak = streak

    const now = new Date()
    const weekDay = now.getDay() === 0 ? 6 : now.getDay() - 1
    const thisMonday = today - weekDay * this.DAY_MS
    const lastMonday = thisMonday - 7 * this.DAY_MS
    let thisWeekNotes = 0
    let lastWeekNotes = 0
    let thisWeekWords = 0
    const weekDays = new Set<number>()

    for (const note of notes) {
      const activityTime = this.noteActivityTime(note)
      if (!activityTime) {
        continue
      }
      const noteDay = this.dayStart(activityTime)
      const words = this.noteWordCount(note)
      if (noteDay >= thisMonday && noteDay < thisMonday + 7 * this.DAY_MS) {
        thisWeekNotes += 1
        thisWeekWords += words
        weekDays.add(noteDay)
      } else if (noteDay >= lastMonday && noteDay < thisMonday) {
        lastWeekNotes += 1
      }
    }

    this.thisWeekNotes = thisWeekNotes
    this.lastWeekNotes = lastWeekNotes
    this.thisWeekWords = thisWeekWords
    this.weekActiveDays = weekDays.size
  }

  computeCategories(): void {
    const categoryMap = new Map<string, number>()
    for (const note of this.noteList) {
      const category = normalizeLearningCategory(note.category)
      categoryMap.set(category, (categoryMap.get(category) ?? 0) + 1)
    }

    const rows = Array.from(categoryMap.entries()).sort((a: [string, number], b: [string, number]) => b[1] - a[1])
    this.topCategoryName = rows.length > 0 ? rows[0][0] : '暂无'
    this.topCategoryCount = rows.length > 0 ? rows[0][1] : 0
    this.categoryNames = rows.slice(0, 5).map((entry: [string, number]) => entry[0])
    this.categoryValues = rows.slice(0, 5).map((entry: [string, number]) => entry[1])
    this.categoryPercents = rows.slice(0, 5).map((entry: [string, number]) =>
      Math.round(entry[1] / Math.max(this.totalNotes, 1) * 100)
    )
  }

  buildInsights(): void {
    const titles: string[] = []
    const bodies: string[] = []
    const colors: string[] = []

    if (this.totalNotes === 0) {
      titles.push('先留下第一条学习痕迹')
      bodies.push('等有了记录，这里会自动长出连续天数、学习画像和本周节奏。')
      colors.push('#cc785c')
      titles.push('从一个很小的切口开始')
      bodies.push('一段语音、一道题、一个疑问都可以成为第一条记录。')
      colors.push('#5db8a6')
      this.insightTitles = titles
      this.insightBodies = bodies
      this.insightColors = colors
      return
    }

    if (this.thisWeekNotes === 0) {
      titles.push('本周还没有新的学习记录')
      bodies.push('先补一条今天的内容，页面的节奏判断才会重新变得准确。')
      colors.push('#cc785c')
    } else if (this.thisWeekNotes >= this.lastWeekNotes && this.thisWeekNotes > 0) {
      titles.push('本周节奏在往上走')
      bodies.push(`已经有 ${this.thisWeekNotes} 条记录，比上周多 ${Math.max(0, this.thisWeekNotes - this.lastWeekNotes)} 条。`)
      colors.push('#5db872')
    } else {
      titles.push('本周节奏有点回落')
      bodies.push(`目前少于上周 ${this.lastWeekNotes - this.thisWeekNotes} 条，适合用短记录把连续感接回来。`)
      colors.push('#e8a55a')
    }

    if (this.topCategoryCount > 0) {
      titles.push(`${this.topCategoryName}是当前主线`)
      bodies.push(`占全部记录 ${this.percent(this.topCategoryCount, this.totalNotes)}%，可以考虑把零散内容整理成一个阶段小结。`)
      colors.push('#5db8a6')
    }

    if (this.totalRecordings > 0) {
      titles.push('语音里藏着可复用内容')
      bodies.push(`已有 ${this.totalRecordings} 段语音速记，建议挑最近几段提炼成知识点。`)
      colors.push('#7c8cf5')
    } else {
      titles.push('可以让记录更轻一点')
      bodies.push('碎片想法不一定要写长文，下一次可以直接用语音补充。')
      colors.push('#7c8cf5')
    }

    this.insightTitles = titles
    this.insightBodies = bodies
    this.insightColors = colors
  }

  dayStart(timestamp: number): number {
    const date = new Date(timestamp)
    return new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime()
  }

  noteActivityTime(note: NoteItem): number {
    return note.lastModifiedTime || note.createTime || 0
  }

  noteWordCount(note: NoteItem): number {
    const text = this.collectNoteText(note).replace(/\s+/g, '')
    return text.length
  }

  collectNoteText(note: NoteItem): string {
    const parts: string[] = []
    if (note.content) {
      parts.push(note.content)
    }

    if (note.richEditorSpans && note.richEditorSpans !== '[]') {
      try {
        const spans = JSON.parse(note.richEditorSpans) as RichEditorSpanStats[]
        for (const span of spans) {
          if (span.type === 'text' && span.value) {
            parts.push(span.value)
          }
          if (span.type === 'link' && span.linkTitle) {
            parts.push(span.linkTitle)
          }
        }
      } catch (e) {
        console.warn('[StatsPage] 解析富文本字数失败:', e)
      }
    }

    if (note.contentBlocks) {
      for (const block of note.contentBlocks) {
        const textBlock = block as TextLikeContentBlockStats
        if (textBlock.type === 'text' && textBlock.text) {
          parts.push(textBlock.text)
        } else if (textBlock.type === 'link' && textBlock.title) {
          parts.push(textBlock.title)
        } else if (textBlock.type === 'checklist' && textBlock.text) {
          parts.push(textBlock.text)
        }
      }
    }

    if (note.recordings) {
      for (const recording of note.recordings) {
        if (recording.transcription) {
          parts.push(recording.transcription)
        }
      }
    }

    return parts.join('')
  }

  formatWordCount(count: number): string {
    if (count >= 10000) {
      return `${(count / 10000).toFixed(1)}万`
    }
    return `${count}`
  }

  percent(count: number, total: number): string {
    return `${Math.round(count / Math.max(total, 1) * 100)}`
  }

  build() {
    Column() {
      Column().width('100%').height(this.topSafeHeight).backgroundColor(AppColors.BG_PRIMARY)

      Row() {
        Column() {
          Text('‹')
            .fontSize(24)
            .fontColor(AppColors.TEXT_PRIMARY)
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .onClick(() => router.back())

        Blank()

        Text('学习洞察')
          .fontSize(AppSizes.FONT_XL)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)

        Blank()
        Column().width(44).height(44)
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Scroll() {
        Column({ space: 18 }) {
          if (this.totalNotes === 0) {
            this.EmptySection()
          } else {
            this.RhythmSection()
            this.CategorySection()
            this.InsightSection()
          }

          Column().height(40)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Column().width('100%').height(this.bottomSafeHeight).backgroundColor(AppColors.BG_PRIMARY)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG_PRIMARY)
  }

  @Builder EmptySection() {
    Column({ space: 14 }) {
      this.SectionTitle('从第一条开始', '记录越轻，统计越有用')
      ForEach(this.insightTitles, (title: string, index: number) => {
        this.InsightCard(title, this.insightBodies[index], this.insightColors[index])
      }, (title: string) => `empty_${title}`)
    }
    .width('100%')
    .opacity(this.contentProgress)
    .translate({ y: this.contentProgress === 0 ? 18 : 0 })
  }

  @Builder RhythmSection() {
    Column({ space: 14 }) {
      this.SectionTitle('学习节奏', '看坚持，也看本周密度')

      Row({ space: 12 }) {
        this.StatTile('当前连续', `${this.currentStreak}`, '天', '#cc785c')
        this.StatTile('最长纪录', `${this.longestStreak}`, '天', '#e8a55a')
      }
      .width('100%')

      Row({ space: 12 }) {
        this.StatTile('本周记录', `${this.thisWeekNotes}`, '条', '#5db8a6')
        this.StatTile('本周字数', this.formatWordCount(this.thisWeekWords), '', '#7c8cf5')
      }
      .width('100%')
    }
    .width('100%')
    .opacity(this.contentProgress)
    .translate({ y: this.contentProgress === 0 ? 18 : 0 })
  }

  @Builder StatTile(label: string, value: string, unit: string, color: string) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(AppSizes.FONT_XS)
        .fontColor(AppColors.TEXT_TERTIARY)
      Row({ space: 3 }) {
        Text(value)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(color)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (unit.length > 0) {
          Text(unit)
            .fontSize(AppSizes.FONT_XS)
            .fontColor(AppColors.TEXT_SECONDARY)
            .margin({ top: 8 })
        }
      }
      .alignItems(VerticalAlign.Bottom)
    }
    .layoutWeight(1)
    .padding({ left: 16, right: 16, top: 15, bottom: 14 })
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .alignItems(HorizontalAlign.Start)
    .shadow(AppShadows.SHADOW_XS)
  }

  @Builder CategorySection() {
    Column({ space: 14 }) {
      this.SectionTitle('学习画像', this.topCategoryCount > 0 ? `${this.topCategoryName}占 ${this.percent(this.topCategoryCount, this.totalNotes)}%` : '暂无分类')

      ForEach(this.categoryNames, (name: string, index: number) => {
        this.CategoryRow(
          name,
          this.categoryValues[index],
          this.categoryPercents[index],
          this.CATEGORY_COLORS[index % this.CATEGORY_COLORS.length]
        )
      }, (name: string) => `category_${name}`)

      Row({ space: 10 }) {
        this.SmallEvidence('语音', `${this.totalRecordings}段`)
        this.SmallEvidence('图片', `${this.totalImages}张`)
        this.SmallEvidence('总字数', this.formatWordCount(this.totalWords))
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .shadow(AppShadows.SHADOW_XS)
    .opacity(this.contentProgress)
    .translate({ y: this.contentProgress === 0 ? 18 : 0 })
  }

  @Builder CategoryRow(name: string, count: number, percent: number, color: string) {
    Column({ space: 7 }) {
      Row() {
        Row({ space: 8 }) {
          Column()
            .width(9)
            .height(9)
            .borderRadius(5)
            .backgroundColor(color)
          Text(name)
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        Text(`${count}条 · ${percent}%`)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.TEXT_TERTIARY)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(8)
          .borderRadius(4)
          .backgroundColor(AppColors.BG_TERTIARY)
        Column()
          .width(`${Math.max(8, percent)}%`)
          .height(8)
          .borderRadius(4)
          .backgroundColor(color)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  @Builder SmallEvidence(label: string, value: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(AppSizes.FONT_SM)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppColors.TEXT_PRIMARY)
      Text(label)
        .fontSize(AppSizes.FONT_2XS)
        .fontColor(AppColors.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(AppColors.BG_TERTIARY)
    .borderRadius(AppSizes.RADIUS_SM)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder InsightSection() {
    Column({ space: 14 }) {
      this.SectionTitle('下一步', '把数据变成一点行动')
      ForEach(this.insightTitles, (title: string, index: number) => {
        this.InsightCard(title, this.insightBodies[index], this.insightColors[index])
      }, (title: string) => `insight_${title}`)
    }
    .width('100%')
    .opacity(this.contentProgress)
    .translate({ y: this.contentProgress === 0 ? 18 : 0 })
  }

  @Builder InsightCard(title: string, body: string, color: string) {
    Row({ space: 12 }) {
      Column()
        .width(4)
        .height(48)
        .borderRadius(2)
        .backgroundColor(color)

      Column({ space: 5 }) {
        Text(title)
          .fontSize(AppSizes.FONT_SM)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(body)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.TEXT_SECONDARY)
          .lineHeight(18)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(AppSizes.RADIUS_MD)
    .shadow(AppShadows.SHADOW_XS)
    .alignItems(VerticalAlign.Center)
  }

  @Builder SectionTitle(title: string, subtitle: string) {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.TEXT_PRIMARY)
        Text(subtitle)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(AppColors.TEXT_TERTIARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }
}
