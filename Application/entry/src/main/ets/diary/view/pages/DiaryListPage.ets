// 学习足迹页面 - 显示历史学习记录
import { router } from '@kit.ArkUI'
import { AppColors, AppSizes, AppShadows, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { CloudDBService } from '../../../common/services/CloudDBService'
import { Diary } from '../../../diary/model/Diary'

@Entry
@Component
struct DiaryListPage {
  @State diaries: Diary[] = []
  @State filteredDiaries: Diary[] = []
  @State isLoading: boolean = true
  @State searchKeyword: string = ''
  @State isFilterMode: boolean = false

  private cloudDBService: CloudDBService = CloudDBService.getInstance()

  async aboutToAppear() {
    // 检查路由参数中是否有搜索关键词
    const params = router.getParams() as Record<string, string> | null
    if (params && params.searchKeyword) {
      this.searchKeyword = params.searchKeyword
      this.isFilterMode = true
    }
    await this.loadDiaries()
  }

  private async loadDiaries(): Promise<void> {
    this.isLoading = true
    try {
      this.diaries = await this.cloudDBService.getDiariesByTime()
      this.filterDiaries()
    } catch (err) {
      console.error('加载学习记录失败:', err)
    }
    this.isLoading = false
  }

  // 根据关键词过滤学习记录
  private filterDiaries(): void {
    if (!this.searchKeyword || this.searchKeyword.length === 0) {
      this.filteredDiaries = this.diaries
      return
    }

    const keyword = this.searchKeyword.toLowerCase()
    this.filteredDiaries = this.diaries.filter((diary: Diary) => {
      const title = (diary.title ?? '').toLowerCase()
      const content = (diary.content ?? '').toLowerCase()
      return title.includes(keyword) || content.includes(keyword)
    })
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部导航栏
        Row() {
        Row() {
          Text('‹')
            .fontSize(28)
            .fontColor(AppColors.TEXT_PRIMARY)
            .fontWeight(FontWeight.Normal)
            .offset({ y: -2 })
        }
        .width(40)
        .height(40)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(AppColors.BG_SECONDARY)
        .borderRadius(20)
        .shadow(AppShadows.SHADOW_XS)
        .onClick(() => router.back())

          Column() {
            Text(this.isFilterMode ? `"${this.searchKeyword}" 相关学习记录` : '学习足迹')
              .fontSize(AppSizes.FONT_XL)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.TEXT_PRIMARY)

            if (this.isFilterMode) {
              Text(`共 ${this.filteredDiaries.length} 篇`)
                .fontSize(AppSizes.FONT_XS)
                .fontColor(AppColors.TEXT_TERTIARY)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: AppSizes.SPACE_LG })

          Blank()

          // 清除筛选按钮（仅在筛选模式下显示）
          if (this.isFilterMode) {
            Button('全部')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.ACCENT)
              .backgroundColor(Color.Transparent)
              .onClick(() => {
                this.searchKeyword = ''
                this.isFilterMode = false
                this.filterDiaries()
              })
              .borderWidth(1)
              .borderColor(AppColors.ACCENT)
              .borderRadius(14)
              .height(28)
          }

          // 新建记录按钮
          Button() {
            Shape() {
              Path()
                .commands(IconPaths.ADD)
                .fill(AppColors.TEXT_WHITE)
            }
            .width(20)
            .height(20)
            .viewPort({ x: 0, y: 0, width: 24, height: 24 })
          }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(AppColors.ACCENT)
          .linearGradient(AppGradients.PRIMARY_BTN)
          .shadow(AppShadows.SHADOW_SM)
          .onClick(() => {
            router.pushUrl({ url: 'diary/view/pages/HomePage' })
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: AppSizes.SPACE_LG, right: AppSizes.SPACE_LG })

        // 学习记录列表
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
            Text('加载中...')
              .fontSize(AppSizes.FONT_SM)
              .fontColor(AppColors.TEXT_TERTIARY)
              .margin({ top: AppSizes.SPACE_MD })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.filteredDiaries.length === 0) {
          this.EmptyState()
        } else {
          this.DiaryList()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.BG_PRIMARY)
    }
    .hideTitleBar(true)
  }

  @Builder
  EmptyState() {
    Column() {
      Text('📔')
        .fontSize(64)

      Text(this.isFilterMode ? '没有找到相关学习记录' : '还没有学习记录')
        .fontSize(AppSizes.FONT_LG)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: AppSizes.SPACE_LG })

      Text(this.isFilterMode ? '试试查看全部记录或换个关键词' : '点击右上角开始记录你的第一条学习记录')
        .fontSize(AppSizes.FONT_SM)
        .fontColor(AppColors.TEXT_HINT)
        .margin({ top: AppSizes.SPACE_SM })

      if (this.isFilterMode) {
        Button('查看全部记录')
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_WHITE)
          .backgroundColor(AppColors.ACCENT)
          .linearGradient(AppGradients.PRIMARY_BTN)
          .borderRadius(AppSizes.RADIUS_LG)
          .shadow(AppShadows.SHADOW_SM)
          .margin({ top: AppSizes.SPACE_LG })
          .onClick(() => {
            this.searchKeyword = ''
            this.isFilterMode = false
            this.filterDiaries()
          })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  DiaryList() {
    Scroll() {
      Column({ space: AppSizes.SPACE_MD }) {
        ForEach(this.groupDiariesByDate(), (group: DiaryGroup) => {
          // 日期分组标题
          Text(group.dateLabel)
            .fontSize(AppSizes.FONT_SM)
            .fontColor(AppColors.TEXT_TERTIARY)
            .width('100%')
            .margin({ top: AppSizes.SPACE_MD })

          // 该日期下的日记
          ForEach(group.diaries, (diary: Diary) => {
            this.DiaryCard(diary)
          })
        })

        Blank().height(AppSizes.SPACE_4XL)
      }
      .padding({
        left: AppSizes.SPACE_2XL,
        right: AppSizes.SPACE_2XL,
        top: AppSizes.SPACE_MD
      })
    }
    .scrollBar(BarState.Off)
    .layoutWeight(1)
  }

  @Builder
  DiaryCard(diary: Diary) {
    Column() {
      // 时间和情绪图标
      Row() {
        Text(this.formatTime(diary.create_time ?? 0))
          .fontSize(AppSizes.FONT_SM)
          .fontColor(AppColors.TEXT_TERTIARY)

        Blank()

        if (diary.mood_emoji) {
          Text(diary.mood_emoji)
            .fontSize(20)
        }
      }
      .width('100%')

      // 标题
      if (diary.title) {
        Text(diary.title)
          .fontSize(AppSizes.FONT_MD)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.TEXT_PRIMARY)
          .margin({ top: AppSizes.SPACE_SM })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      // 内容预览
      Text(diary.content ?? '')
        .fontSize(AppSizes.FONT_SM)
        .fontColor(AppColors.TEXT_SECONDARY)
        .margin({ top: AppSizes.SPACE_XS })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    }
    .width('100%')
    .padding(AppSizes.SPACE_LG)
    .padding(AppSizes.SPACE_LG)
    .backgroundColor(AppColors.BG_SECONDARY)
    .linearGradient(AppGradients.CARD_SUBTLE)
    .borderRadius(AppSizes.RADIUS_LG)
    .shadow(AppShadows.SHADOW_SM)
    .onClick(() => {
      router.pushUrl({
        url: 'diary/view/pages/DetailPage',
        params: { diary: diary }
      })
    })
  }

  // 按日期分组日记
  private groupDiariesByDate(): DiaryGroup[] {
    const groups: Map<string, Diary[]> = new Map()

    for (const diary of this.filteredDiaries) {
      const dateLabel = this.formatDateLabel(diary.create_time ?? 0)
      if (!groups.has(dateLabel)) {
        groups.set(dateLabel, [])
      }
      groups.get(dateLabel)!.push(diary)
    }

    const result: DiaryGroup[] = []
    groups.forEach((diaries, dateLabel) => {
      result.push({ dateLabel, diaries })
    })

    return result
  }

  private formatDateLabel(timestamp: number): string {
    const date = new Date(timestamp)
    const today = new Date()
    const yesterday = new Date(today)
    yesterday.setDate(yesterday.getDate() - 1)

    if (this.isSameDay(date, today)) return '今天'
    if (this.isSameDay(date, yesterday)) return '昨天'

    return `${date.getMonth() + 1}月${date.getDate()}日`
  }

  private isSameDay(d1: Date, d2: Date): boolean {
    return d1.getFullYear() === d2.getFullYear() &&
      d1.getMonth() === d2.getMonth() &&
      d1.getDate() === d2.getDate()
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${hours}:${minutes}`
  }
}

// 日记分组
interface DiaryGroup {
  dateLabel: string
  diaries: Diary[]
}
