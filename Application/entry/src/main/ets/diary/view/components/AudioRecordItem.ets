
import { RecordingItem } from '../../model/RecordingItem'
import { AppColors, AppSizes, AppShadows, AppGradients, LinearGradient } from '../../../common/utils/AppTheme'
import { IconPaths } from '../../../common/utils/IconPaths'
import { promptAction } from '@kit.ArkUI'

@Component
export struct AudioRecordItem {
  @ObjectLink recording: RecordingItem
  @Prop currentPlayingId: string
  @Prop playbackProgress: number
  
  // Callbacks
  onPlay: (item: RecordingItem) => void = () => {}
  onDelete: (item: RecordingItem) => void = () => {}
  onRename: (id: string, name: string) => void = () => {}
  onSeek: (item: RecordingItem, value: number) => void = () => {}

  // Local state for renaming
  @State private isRenaming: boolean = false
  @State private tempName: string = ''

  build() {
    Column({ space: 0 }) {
      // 主要控制行
      Row() {
        // 播放/暂停按钮 - 自绘图标 + 渐变设计
        Stack() {
          // 外圈光晕（播放时显示）
          if (this.currentPlayingId === this.recording.id) {
            Circle()
              .width(52)
              .height(52)
              .fill(Color.Transparent)
              .stroke(AppColors.ACCENT)
              .strokeWidth(1.5)
              .opacity(0.3)
          }

          Column() {
            if (this.currentPlayingId === this.recording.id) {
              // 暂停图标 - 双竖线（稍微放大）
              Row({ space: 5 }) {
                Column().width(5).height(16).backgroundColor(AppColors.TEXT_WHITE).borderRadius(1)
                Column().width(5).height(16).backgroundColor(AppColors.TEXT_WHITE).borderRadius(1)
              }
            } else {
              // 播放图标 - 更大更清晰的三角形
              Stack() {
                // 用Column画三角形 - 尺寸加大
                Column()
                  .width(0)
                  .height(0)
                  .border({
                    width: {
                      left: 18,
                      top: 11,
                      bottom: 11,
                      right: 0
                    },
                    color: {
                      left: AppColors.TEXT_WHITE,
                      top: Color.Transparent,
                      bottom: Color.Transparent,
                      right: Color.Transparent
                    }
                  })
              }
              .margin({ left: 4 })
            }
          }
          .width(44)
          .height(44)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(22)
          .backgroundColor('#292524') // 深灰色
        }
        .onClick(() => {
          this.onPlay(this.recording)
        })

        // 录音信息
        Column({ space: 4 }) {
          // 录音名称 - 支持点击编辑
          if (this.isRenaming) {
            TextInput({ text: this.tempName })
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .backgroundColor(AppColors.BG_TERTIARY)
              .borderRadius(6)
              .padding({
                left: 8,
                right: 8,
                top: 4,
                bottom: 4
              })
              .height(32)
              .onChange((value: string) => {
                this.tempName = value
              })
              .onSubmit(() => {
                 this.handleRename()
              })
              .onBlur(() => {
                 this.handleRename()
              })
          } else {
            Text(this.recording.name || '录音')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.TEXT_PRIMARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.isRenaming = true
                this.tempName = this.recording.name || '录音'
              })
          }

          Row({ space: 8 }) {
            // 时长标签 - 纯文字
            Text(this.formatDuration(this.recording.audioDuration))
              .fontSize(12)
              .fontColor(AppColors.TEXT_TERTIARY)

            // 日期时间（如果有）
            if (this.recording.createTime) {
              Text('•')
                .fontSize(10)
                .fontColor(AppColors.TEXT_HINT)
              Text(this.formatTimeAgo(this.recording.createTime))
                .fontSize(12)
                .fontColor(AppColors.TEXT_TERTIARY)
            }
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 14 })
        .layoutWeight(1)

        // 删除按钮 - 自绘关闭图标
        Column() {
          Path()
            .width(12)
            .height(12)
            .commands(IconPaths.CLOSE)
            .fill(AppColors.TEXT_HINT)
        }
        .width(28)
        .height(28)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius(14)
        .backgroundColor(AppColors.BG_TERTIARY)
        .onClick(() => {
          this.onDelete(this.recording)
        })
      }
      .width('100%')

      // 播放进度条 - 仅在有时长时显示
      if (this.recording.audioDuration > 0) {
        Column({ space: 8 }) {
          // 进度滑块 - 更细腻
          Slider({
            value: this.currentPlayingId === this.recording.id ? this.playbackProgress : 0,
            min: 0,
            max: this.recording.audioDuration > 0 ? this.recording.audioDuration : 1,
            step: 0.1
          })
            .width('100%')
            .blockColor(AppColors.ACCENT)
            .trackColor(AppColors.BORDER_LIGHT)
            .selectedColor(AppColors.ACCENT)
            .showSteps(false)
            .trackThickness(2)
            .onChange((value: number, mode: SliderChangeMode) => {
              if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
                this.onSeek(this.recording, value)
              }
            })

          // 时间显示
          Row() {
            Text(this.currentPlayingId === this.recording.id ? this.formatDuration(this.playbackProgress) : '0:00')
              .fontSize(11)
              .fontColor(AppColors.TEXT_HINT)
              .fontWeight(FontWeight.Medium)
            Blank()
            Text(this.formatDuration(this.recording.audioDuration))
              .fontSize(11)
              .fontColor(AppColors.TEXT_HINT)
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ top: 14 })
      }

      // 转写文字区域 - 优雅卡片式
      if (this.recording.transcription) {
        Column({ space: 6 }) {
          Row({ space: 6 }) {
            Path()
              .width(10)
              .height(10)
              .commands(IconPaths.STAR)
              .fill(AppColors.BRAND_AMBER)
            Text('语音转文字')
              .fontSize(11)
              .fontColor(AppColors.TEXT_TERTIARY)
              .fontWeight(FontWeight.Medium)
          }

          Text(this.recording.transcription)
            .fontSize(14)
            .fontColor(AppColors.TEXT_SECONDARY)
            .lineHeight(22)
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: 14,
          right: 14,
          top: 12,
          bottom: 12
        })
        .margin({ top: 14 })
        .backgroundColor(AppColors.BG_TERTIARY)
        .borderRadius(10)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.BG_SECONDARY)
    .borderRadius(16)
    .border({ width: 0.5, color: AppColors.BORDER_LIGHT })
    .shadow({
      radius: 8,
      color: '#0000000A',
      offsetX: 0,
      offsetY: 2
    })
    .margin({ top: 8, bottom: 8 })
  }

  private handleRename() {
    if (this.isRenaming && this.tempName !== this.recording.name) {
       this.onRename(this.recording.id, this.tempName)
    }
    this.isRenaming = false
  }

  /** 格式化时长 (秒 -> mm:ss) */
  private formatDuration(seconds: number): string {
    if (!seconds || seconds < 0) return '0:00'
    const m = Math.floor(seconds / 60)
    const s = Math.floor(seconds % 60)
    return `${m}:${s.toString().padStart(2, '0')}`
  }

  /** 格式化时间为 24小时制 (yyyy/MM/dd HH:mm) */
  private formatTimeAgo(timestamp: number): string {
    const date = new Date(timestamp)
    const y = date.getFullYear()
    const M = date.getMonth() + 1
    const d = date.getDate()
    const h = date.getHours().toString().padStart(2, '0')
    const m = date.getMinutes().toString().padStart(2, '0')
    return `${y}/${M}/${d} ${h}:${m}`
  }
}
