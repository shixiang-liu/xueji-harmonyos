import { NoteItem } from '../../model/NoteItem'
import { AppColors, AppShadows, AppSizes, AppAnimations, AppThemeManager } from '../../../common/utils/AppTheme'
import { normalizeLearningCategory } from '../../utils/LearningCategories'

@Component
export struct LearningRecordCard {
  note: NoteItem = new NoteItem()
  @Prop isSelected: boolean = false
  @Prop isPressed: boolean = false
  @Prop isMultiSelectMode: boolean = false
  onOpen: (noteId: string) => void = () => {}
  onToggleSelect: (noteId: string) => void = () => {}
  onLongPress: (noteId: string) => void = () => {}
  onPressChange: (noteId: string, pressed: boolean) => void = () => {}

  private longPressTimer: number = 0

  build() {
    Row({ space: AppSizes.SPACE_MD }) {
      if (this.isMultiSelectMode) {
        this.SelectionMark()
      }

      Column({ space: 10 }) {
        this.TitleRow()
        this.Excerpt()
        this.MetaRow()
        this.ContextRow()
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(AppSizes.SPACE_LG)
    .backgroundColor(this.cardBackground())
    .borderRadius(12)
    .border({ width: 1, color: this.cardBorderColor() })
    .shadow(this.isPressed || this.isDarkMode() ? undefined : AppShadows.SHADOW_SM)
    .animation(AppAnimations.SPRING_FAST)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.longPressTimer = setTimeout(() => {
          this.onLongPress(this.note.id)
        }, 500)
        if (!this.isMultiSelectMode) {
          this.onPressChange(this.note.id, true)
        }
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        clearTimeout(this.longPressTimer)
        if (!this.isMultiSelectMode) {
          this.onPressChange(this.note.id, false)
        }
      }
    })
    .onClick(() => {
      if (this.isMultiSelectMode) {
        this.onToggleSelect(this.note.id)
        return
      }
      this.onOpen(this.note.id)
    })
  }

  @Builder
  SelectionMark() {
    Column() {
      if (this.isSelected) {
        Column() {
          Text('✓')
            .fontSize(12)
            .fontColor(AppColors.TEXT_WHITE)
            .fontWeight(FontWeight.Bold)
        }
        .width(24)
        .height(24)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(12)
        .backgroundColor('#cc785c')
        .shadow(AppShadows.SHADOW_SM)
      } else {
        Circle()
          .width(24)
          .height(24)
          .fill(Color.Transparent)
          .stroke(this.cardBorderColor())
          .strokeWidth(2)
      }
    }
    .width(32)
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TitleRow() {
    Row() {
      Column({ space: 3 }) {
        Text(this.note.title || '无标题记录')
          .fontSize(AppSizes.FONT_LG)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.primaryTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.formatFullDate(this.note.createTime || 0))
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.metaTextColor())
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        if (this.note.isFavorite) {
          Text('★')
            .fontSize(14)
            .fontColor('#e8a55a')
        }
        if (this.note.isLocked) {
          Text('隐私')
            .fontSize(11)
            .fontColor(this.subtleTextColor())
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.privacyTagBackground())
            .borderRadius(8)
        }
      }
    }
    .width('100%')
  }

  @Builder
  Excerpt() {
    if (this.note.isLocked) {
      Text('此记录已开启隐私保护，点击输入密码查看')
        .fontSize(AppSizes.FONT_SM)
        .fontColor(this.metaTextColor())
        .fontStyle(FontStyle.Italic)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
    } else {
      Text(this.excerptText())
        .fontSize(AppSizes.FONT_MD)
        .fontColor(this.bodyTextColor())
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .lineHeight(23)
    }
  }

  @Builder
  MetaRow() {
    Row({ space: 8 }) {
      this.Tag(this.categoryText(), '#cc785c', 'rgba(204, 120, 92, 0.12)')

      if (this.hasImage()) {
        this.Tag('图片', '#5db8a6', 'rgba(93, 184, 166, 0.14)')
      }
      if (this.hasVideo()) {
        this.Tag('视频', '#a9583e', 'rgba(169, 88, 62, 0.12)')
      }
      if (this.hasAudio()) {
        this.Tag(`语音 ${this.audioCount()}`, '#c64545', 'rgba(198, 69, 69, 0.10)')
      }

      Blank()
    }
    .width('100%')
  }

  @Builder
  ContextRow() {
    Row({ space: 8 }) {
      if (this.locationText().length > 0) {
        Text(`地点 · ${this.locationText()}`)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.subtleTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      } else {
        Text('本地已保存')
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.metaTextColor())
          .layoutWeight(1)
      }

      if (this.moodText().length > 0) {
        Text(`学习心情 · ${this.moodText()}`)
          .fontSize(AppSizes.FONT_XS)
          .fontColor(this.subtleTextColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
  }

  @Builder
  Tag(text: string, color: string, bg: string) {
    Text(text)
      .fontSize(AppSizes.FONT_XS)
      .fontWeight(FontWeight.Medium)
      .fontColor(color)
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor(this.tagBackground(bg))
      .borderRadius(8)
  }

  private cardBackground(): string {
    if (this.isSelected) {
      return this.isDarkMode() ? 'rgba(204, 120, 92, 0.22)' : 'rgba(204, 120, 92, 0.12)'
    }
    if (this.isDarkMode()) {
      return this.isPressed ? AppColors.BG_DARK_TERTIARY : AppColors.BG_DARK_SECONDARY
    }
    return this.isPressed ? '#f5f0e8' : '#faf9f5'
  }

  private cardBorderColor(): string {
    return this.isDarkMode() ? AppColors.BORDER_DARK : '#e6dfd8'
  }

  private primaryTextColor(): string {
    return this.isDarkMode() ? AppColors.TEXT_DARK_PRIMARY : '#141413'
  }

  private bodyTextColor(): string {
    return this.isDarkMode() ? AppColors.TEXT_DARK_SECONDARY : '#3d3d3a'
  }

  private metaTextColor(): string {
    return this.isDarkMode() ? AppColors.TEXT_DARK_TERTIARY : '#8e8b82'
  }

  private subtleTextColor(): string {
    return this.isDarkMode() ? AppColors.TEXT_DARK_SECONDARY : '#6c6a64'
  }

  private privacyTagBackground(): string {
    return this.isDarkMode() ? 'rgba(255, 255, 255, 0.08)' : '#f5f0e8'
  }

  private tagBackground(bg: string): string {
    return this.isDarkMode() ? bg.replace('0.10)', '0.20)').replace('0.12)', '0.22)').replace('0.14)', '0.24)') : bg
  }

  private isDarkMode(): boolean {
    return AppThemeManager.isDarkMode()
  }

  private categoryText(): string {
    return normalizeLearningCategory(this.note.category)
  }

  private excerptText(): string {
    const content = (this.note.content || '').trim().split('\n').join(' ')
    if (content.length > 0) {
      return content
    }
    if (this.hasImage() || this.hasVideo() || this.hasAudio()) {
      return '包含多媒体学习记录'
    }
    return '暂无正文内容'
  }

  private locationText(): string {
    const name = (this.note.locationName || '').trim()
    if (name.length > 0) {
      return name
    }
    return (this.note.locationAddress || '').trim()
  }

  private moodText(): string {
    const emoji = (this.note.learningMoodEmoji || this.note.emotionEmoji || '').trim()
    const label = (this.note.learningMoodLabel || this.note.emotionLabel || '').trim()
    if (emoji.length > 0 && label.length > 0) {
      return `${emoji} ${label}`
    }
    if (label.length > 0) {
      return label
    }
    return emoji
  }

  private hasImage(): boolean {
    return this.note.hasImage ||
      (this.note.images && this.note.images.length > 0) ||
      this.hasContentBlockType('image')
  }

  private hasVideo(): boolean {
    return this.note.hasVideo ||
      (this.note.videos && this.note.videos.length > 0) ||
      this.hasContentBlockType('video')
  }

  private hasAudio(): boolean {
    return this.note.hasAudio || (this.note.recordings && this.note.recordings.length > 0)
  }

  private audioCount(): number {
    return this.note.recordings ? this.note.recordings.length : 0
  }

  private hasContentBlockType(type: string): boolean {
    if (!this.note.contentBlocks) {
      return false
    }
    for (let i = 0; i < this.note.contentBlocks.length; i++) {
      if (this.note.contentBlocks[i].type === type) {
        return true
      }
    }
    return false
  }

  private formatFullDate(timestamp: number): string {
    if (!timestamp) {
      return ''
    }
    const d = new Date(timestamp)
    const year = d.getFullYear()
    const month = d.getMonth() + 1
    const day = d.getDate()
    const hour = d.getHours().toString().padStart(2, '0')
    const min = d.getMinutes().toString().padStart(2, '0')
    return `${year}年${month}月${day}日 ${hour}:${min}`
  }
}
