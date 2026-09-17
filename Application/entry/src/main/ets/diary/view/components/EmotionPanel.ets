
import { AppColors, AppShadows, AppGradients, AppSizes, LinearGradient } from '../../../common/utils/AppTheme'
import { EMOTION_PRESETS, EmotionPreset } from '../../../common/utils/EmotionAnalyzer'

@Component
export struct EmotionPanel {
  @Link showPanel: boolean
  @Prop isAnalyzing: boolean
  @Prop statusText: string
  @Prop selectedEmoji: string
  @Prop selectedLabel: string
  @Prop selectedKey: string
  @Prop weatherIcon: string
  @Prop weatherLabel: string
  @Prop themeColor: string // string color
  @Prop errorText: string

  onRetry: () => void = () => {}
  onSelectPreset: (preset: EmotionPreset) => void = () => {}

  build() {
    Column({ space: 0 }) {
      // 顶部把手
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor(AppColors.DIVIDER_DARK)
        .margin({ top: 12, bottom: 20 })

      // 标题栏
      Row() {
        Column({ space: 4 }) {
          Text('今日情绪')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_PRIMARY)
            .letterSpacing(0.5)
          Text(this.statusText)
            .fontSize(12)
            .fontColor(AppColors.TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 重新分析按钮 - 优雅胶囊
        Row({ space: 6 }) {
          Text(this.isAnalyzing ? '◐' : '↻')
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
          Text(this.isAnalyzing ? '分析中' : 'AI 分析')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.TEXT_SECONDARY)
        }
        .padding({
          left: 14,
          right: 14,
          top: 8,
          bottom: 8
        })
        .backgroundColor(AppColors.BG_TERTIARY)
        .linearGradient(AppGradients.CARD_SUBTLE)
        .borderRadius(16)
        .onClick(() => {
          if (!this.isAnalyzing) {
            this.onRetry()
          }
        })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 当前情绪展示卡片
      Row({ space: 0 }) {
        // 心情
        Column({ space: 8 }) {
          Text('心情')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
          Column({ space: 4 }) {
            Text(this.selectedEmoji)
              .fontSize(32)
            Text(this.selectedLabel)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 16, bottom: 16 })

        // 分割线
        Column()
          .width(1)
          .height(60)
          .backgroundColor(AppColors.DIVIDER)

        // 天气
        Column({ space: 8 }) {
          Text('天气')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
          Column({ space: 4 }) {
            Text(this.weatherIcon)
              .fontSize(32)
            Text(this.weatherLabel)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 16, bottom: 16 })

        // 分割线
        Column()
          .width(1)
          .height(60)
          .backgroundColor(AppColors.DIVIDER)

        // 颜色
        Column({ space: 8 }) {
          Text('主题色')
            .fontSize(11)
            .fontColor(AppColors.TEXT_TERTIARY)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1)
          Column({ space: 4 }) {
            Column()
              .width(32)
              .height(32)
              .borderRadius(16)
              .backgroundColor(this.themeColor)
              .shadow({
                radius: 8,
                color: this.themeColor + '40',
                offsetX: 0,
                offsetY: 4
              })
            Text(' ')
              .fontSize(13)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 16, bottom: 16 })
      }
      .width('100%')
      .margin({ top: 20 })
      .padding({ left: 8, right: 8 })
      .backgroundColor(AppColors.BG_SECONDARY)
      .borderRadius(16)
      .margin({ left: 24, right: 24, top: 20 })
      .shadow(AppShadows.SHADOW_SM)

      // 错误提示
      if (this.errorText) {
        Text(this.errorText)
          .fontSize(12)
          .fontColor(AppColors.ERROR)
          .padding({ left: 24, right: 24, top: 12 })
      }

      // 情绪预设选择 - 精致网格
      Column({ space: 12 }) {
        Text('选择情绪')
          .fontSize(11)
          .fontColor(AppColors.TEXT_TERTIARY)
          .fontWeight(FontWeight.Medium)
          .letterSpacing(1)
          .alignSelf(ItemAlign.Start)

        Scroll() {
          Row({ space: 12 }) {
            ForEach(EMOTION_PRESETS, (preset: EmotionPreset) => {
              Column({ space: 6 }) {
                Text(preset.emoji)
                  .fontSize(28)
                Text(preset.label)
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.selectedKey === preset.key ? AppColors.TEXT_PRIMARY : AppColors.TEXT_SECONDARY)
              }
              .width(64)
              .height(72)
              .justifyContent(FlexAlign.Center)
              .backgroundColor(this.selectedKey === preset.key ? AppColors.BG_SECONDARY : AppColors.BG_TERTIARY)
              .linearGradient(this.selectedKey === preset.key ? AppGradients.SPA_SKY : undefined)
              .borderRadius(16)
              .border({
                width: this.selectedKey === preset.key ? 0 : 0, // Remove border if using gradient background
                color: 'transparent'
              })
              .shadow(this.selectedKey === preset.key ?
                AppShadows.SHADOW_SM :
                {
                  radius: 0,
                  color: 'transparent',
                  offsetX: 0,
                  offsetY: 0
                })
              .onClick(() => {
                this.onSelectPreset(preset)
              })
            })
          }
          .padding({
            left: 4,
            right: 4,
            top: 4,
            bottom: 4
          })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20 })
      .alignItems(HorizontalAlign.Start)

      // 底部提示 - 更优雅
      Text('AI 会根据文字内容自动匹配心情，也可手动选择')
        .fontSize(12)
        .fontColor(AppColors.TEXT_TERTIARY)
        .textAlign(TextAlign.Center)
        .padding({ top: 20, bottom: 8 })
    }
    .width('100%')
    .padding({ bottom: 24 })
    .backgroundColor(AppColors.BG_PRIMARY)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow(AppShadows.SHADOW_LG)
  }
}
